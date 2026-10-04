import CombatPadKit
import SwiftUI

/// Plans one encounter: a tab per difficulty variant, each with its creatures, bench, events and budget.
struct EncounterEditorView: View {
    let encounter: Encounter
    @Environment(AppModel.self) private var model
    @State private var label = ""
    @State private var partyID: UUID?
    @State private var isBrowsing = false
    @State private var isAddingCustom = false
    @State private var editingEvent: EncounterEvent?
    @State private var isConfirmingStartOver = false

    var body: some View {
        let scenario = model.scenario(encounter.scenarioID)
        let current = model.encounter(encounter.id) ?? encounter
        Form {
            Section {
                TextField("Name", text: textBinding(\.name)).titleEntry()
                TextField("Location", text: textBinding(\.location), prompt: Text("A3. Docks")).titleEntry()
                TextField("Notes", text: textBinding(\.notes), axis: .vertical).lineLimit(2...10)
            }
            Section {
                variantControls(labels: scenario?.variantLabels ?? [])
                if let party = model.party(partyID) { budget(for: current.variant(label), party: party) }
            }
            SlotsSection(encounter: current, label: label, party: model.party(partyID),
                         isBrowsing: $isBrowsing, isAddingCustom: $isAddingCustom)
            EventsSection(encounter: current, label: label, editingEvent: $editingEvent)
        }
        .formStyle(.grouped)
        .modifier(StatBlockImportModifier(encounterID: encounter.id, label: label))
        .navigationTitle(current.name)
        .toolbar { runButton(current) }
        .onAppear { setUp(scenario) }
        .onChange(of: encounter.id) { setUp(scenario) }
        .onChange(of: partyID) { if let label = challengePointLabel(scenario) { self.label = label } }
        .sheet(isPresented: $isBrowsing) {
            BestiaryBrowser(game: model.game, partyLevel: model.party(partyID)?.level) { key in addCreature(key) }
        }
        .sheet(isPresented: $isAddingCustom) {
            if let scenario {
                CustomCreatureEditor(custom: newCustomCreature(in: scenario)) { custom in
                    model.library.save(custom)
                    addSlot(EncounterSlot(creatureKey: custom.key))
                }
            }
        }
        .sheet(item: $editingEvent) { event in
            EventEditor(event: event, slots: current.variant(label).slots) { saveEvent($0) }
        }
    }

    @ViewBuilder
    private func variantControls(labels: [String]) -> some View {
        if labels.count > 1 {
            Picker("Difficulty", selection: $label) {
                ForEach(labels, id: \.self) { Text($0).tag($0) }
            }
            .pickerStyle(.segmented)
            Menu("Copy from another difficulty") {
                ForEach(labels.filter { $0 != label }, id: \.self) { source in
                    Button(source) {
                        let target = label
                        model.changeVariant(encounterID: encounter.id, variantLabel: target) {
                            update { $0.copyVariant(from: source, to: target) }
                        }
                    }
                }
            }
        }
        PartyPicker(campaignID: model.scenario(encounter.scenarioID)?.campaignID ?? UUID(), partyID: $partyID)
        ChallengePointsLine(scenario: model.scenario(encounter.scenarioID), party: model.party(partyID))
    }

    private func budget(for variant: EncounterVariant, party: Party) -> some View {
        let budget = party.budget
        return BudgetBar(experience: budget.experience(of: variant) { model.entry($0) }, budget: budget)
    }

    /// Run, or Resume when a fight is in progress, with Start Over in its menu.
    @ViewBuilder
    private func runButton(_ current: Encounter) -> some View {
        if model.inProgressSession(encounterID: current.id, variantLabel: label) != nil {
            Menu {
                Button("Start Over…", systemImage: "arrow.counterclockwise", role: .destructive) {
                    isConfirmingStartOver = true
                }
            } label: {
                Label("Resume", systemImage: "play.fill")
            } primaryAction: {
                model.startCombat(encounter: current, variantLabel: label, party: model.party(partyID))
            }
            .help("Return to the fight in progress at \(label)")
            .confirmationDialog("Start this fight over?", isPresented: $isConfirmingStartOver,
                                titleVisibility: .visible) {
                Button("Start Over", role: .destructive) {
                    model.startOver(encounter: current, variantLabel: label, party: model.party(partyID))
                }
            } message: {
                Text("The fight in progress ends, and a new one starts from the plan.")
            }
        } else {
            Button("Run", systemImage: "play.fill") {
                model.startCombat(encounter: current, variantLabel: label, party: model.party(partyID))
            }
            .disabled(current.variant(label).slots.isEmpty)
            .help("Start this encounter at \(label)")
        }
    }

    /// Picks the difficulty: the one the party's challenge points call for, else the last one run.
    private func setUp(_ scenario: Scenario?) {
        partyID = partyID ?? model.defaultParty(for: scenario?.campaignID)?.id
        let labels = scenario?.variantLabels ?? [VariantScheme.single.labels[0]]
        let last = scenario?.lastVariantLabel ?? ""
        label = challengePointLabel(scenario) ?? (labels.contains(last) ? last : labels[0])
    }

    private func challengePointLabel(_ scenario: Scenario?) -> String? {
        guard let scenario, let points = model.party(partyID)?.challengePoints(levelRange: scenario.levelRange)
        else { return nil }
        return ChallengePoints.label(for: points, among: scenario.variantLabels)
    }

    // MARK: Changes

    private func update(_ change: (inout Encounter) -> Void) {
        var edited = model.encounter(encounter.id) ?? encounter
        change(&edited)
        model.library.save(edited)
    }

    /// Changes the difficulty's creatures or events, asking first if that would reset a fight in progress.
    private func updateVariant(_ change: @escaping (inout EncounterVariant) -> Void) {
        let label = label
        model.changeVariant(encounterID: encounter.id, variantLabel: label) {
            update { encounter in
                var variant = encounter.variant(label)
                change(&variant)
                encounter.setVariant(variant)
            }
        }
    }

    private func addCreature(_ key: String) {
        updateVariant { variant in
            if let index = variant.slots.firstIndex(where: { $0.creatureKey == key && $0.template == .normal }) {
                variant.slots[index].count += 1
            } else {
                variant.slots.append(EncounterSlot(creatureKey: key))
            }
        }
    }

    private func newCustomCreature(in scenario: Scenario) -> CustomCreature {
        var custom = CustomCreature(campaignID: scenario.campaignID, game: model.game, name: "")
        custom.scenarioID = scenario.id
        return custom
    }

    private func addSlot(_ slot: EncounterSlot) {
        updateVariant { $0.slots.append(slot) }
    }

    private func saveEvent(_ event: EncounterEvent) {
        updateVariant { variant in
            if let index = variant.events.firstIndex(where: { $0.id == event.id }) {
                variant.events[index] = event
            } else {
                variant.events.append(event)
            }
        }
    }

    private func textBinding(_ path: WritableKeyPath<Encounter, String>) -> Binding<String> {
        Binding(get: { (model.encounter(encounter.id) ?? encounter)[keyPath: path] },
                set: { value in update { $0[keyPath: path] = value } })
    }
}
