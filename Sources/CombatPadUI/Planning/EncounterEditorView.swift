import CombatPadKit
import SwiftUI

/// Plans one encounter: a tab per difficulty variant, each with its creatures, bench, events and budget.
struct EncounterEditorView: View {
    let encounter: Encounter
    @Environment(AppModel.self) private var model
    @State private var label = ""
    @State private var partyID: UUID?
    @State private var isBrowsing = false
    @State private var isAddingNPC = false
    @State private var editingEvent: EncounterEvent?

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
                         isBrowsing: $isBrowsing, isAddingNPC: $isAddingNPC)
            EventsSection(encounter: current, label: label, editingEvent: $editingEvent)
        }
        .formStyle(.grouped)
        .navigationTitle(current.name)
        .toolbar { runButton(current) }
        .onAppear { setUp(scenario) }
        .onChange(of: encounter.id) { setUp(scenario) }
        .sheet(isPresented: $isBrowsing) {
            BestiaryBrowser(game: model.game, partyLevel: model.party(partyID)?.level) { key in addCreature(key) }
        }
        .sheet(isPresented: $isAddingNPC) { CustomNPCSheet { slot in addSlot(slot) } }
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
                    Button(source) { update { $0.copyVariant(from: source, to: label) } }
                }
            }
        }
        PartyPicker(campaignID: model.scenario(encounter.scenarioID)?.campaignID ?? UUID(), partyID: $partyID)
    }

    private func budget(for variant: EncounterVariant, party: Party) -> some View {
        let budget = EncounterBudget(partyLevel: party.level, partySize: party.members.count)
        return BudgetBar(experience: budget.experience(of: variant) { model.entry($0) }, budget: budget)
    }

    private func runButton(_ current: Encounter) -> some View {
        Button("Run", systemImage: "play.fill") {
            model.startCombat(encounter: current, variantLabel: label, party: model.party(partyID))
        }
        .disabled(current.variant(label).slots.isEmpty)
        .help("Start this encounter at \(label)")
    }

    private func setUp(_ scenario: Scenario?) {
        let labels = scenario?.variantLabels ?? [VariantScheme.single.labels[0]]
        let last = scenario?.lastVariantLabel ?? ""
        label = labels.contains(last) ? last : labels[0]
        partyID = partyID ?? model.defaultParty(for: scenario?.campaignID)?.id
    }

    // MARK: Changes

    private func update(_ change: (inout Encounter) -> Void) {
        var edited = model.encounter(encounter.id) ?? encounter
        change(&edited)
        model.library.save(edited)
    }

    private func updateVariant(_ change: (inout EncounterVariant) -> Void) {
        update { encounter in
            var variant = encounter.variant(label)
            change(&variant)
            encounter.setVariant(variant)
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
