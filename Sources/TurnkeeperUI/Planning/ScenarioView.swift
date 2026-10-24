import TurnkeeperKit
import SwiftUI

/// A scenario's details and the grid of every encounter at every difficulty, with XP and threat.
struct ScenarioView: View {
    let scenario: Scenario
    @Environment(AppModel.self) private var model
    @State private var partyID: UUID?

    var body: some View {
        Form {
            Section {
                TextField("Name", text: binding(\.name)).titleEntry()
                TextField("Levels", text: binding(\.levelRange), prompt: Text("1–4"))
                HStack {
                    TextField("Variants, comma separated", text: labelsBinding)
                    Menu("Presets") {
                        ForEach(VariantScheme.allCases, id: \.self) { scheme in
                            Button(scheme.title) { update { $0.variantLabels = scheme.labels } }
                        }
                    }
                    .fixedSize()
                }
                TextField("Notes", text: binding(\.notes), axis: .vertical).lineLimit(3...8)
            }
            Section {
                PartyPicker(campaignID: scenario.campaignID, partyID: $partyID)
                ChallengePointsLine(scenario: scenario, party: model.party(partyID))
                ScenarioGrid(scenario: scenario, party: model.party(partyID))
            } header: {
                Text("Encounters by difficulty")
            }
        }
        .formStyle(.grouped)
        .navigationTitle(scenario.name)
        .toolbar {
            Button("Add Encounter", systemImage: "plus") { model.addEncounter(to: scenario.id) }
        }
        .onAppear { partyID = partyID ?? model.defaultParty(for: scenario.campaignID)?.id }
    }

    private func update(_ change: (inout Scenario) -> Void) {
        var edited = model.scenario(scenario.id) ?? scenario
        change(&edited)
        model.library.save(edited)
    }

    private func binding(_ path: WritableKeyPath<Scenario, String>) -> Binding<String> {
        Binding(get: { (model.scenario(scenario.id) ?? scenario)[keyPath: path] },
                set: { value in update { $0[keyPath: path] = value } })
    }

    private var labelsBinding: Binding<String> {
        Binding(get: { scenario.variantLabels.joined(separator: ", ") },
                set: { text in
                    let labels = text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    update { $0.variantLabels = labels.filter { !$0.isEmpty } }
                })
    }
}

/// Picks the party whose level and size the budgets use.
struct PartyPicker: View {
    let campaignID: UUID
    @Binding var partyID: UUID?
    @Environment(AppModel.self) private var model

    var body: some View {
        Picker("Party", selection: $partyID) {
            Text("None").tag(UUID?.none)
            ForEach(model.library.parties(in: campaignID)) { party in
                Text("\(party.name) (level \(party.level), \(party.presentMembers.count) PCs)")
                    .tag(UUID?.some(party.id))
            }
        }
    }
}

/// Rows are encounters, columns are difficulty variants; each cell shows XP and threat and can start the fight.
private struct ScenarioGrid: View {
    let scenario: Scenario
    let party: Party?
    @Environment(AppModel.self) private var model

    var body: some View {
        let encounters = model.library.encounters(in: scenario.id)
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
            GridRow {
                Text("")
                ForEach(scenario.variantLabels, id: \.self) { Text($0).font(.caption.bold()) }
            }
            ForEach(encounters) { encounter in
                GridRow {
                    Button(encounter.name) { model.selection = .encounter(encounter.id) }
                        .buttonStyle(.borderless)
                    ForEach(scenario.variantLabels, id: \.self) { label in
                        cell(encounter, label)
                    }
                }
            }
        }
        if encounters.isEmpty {
            Text("No encounters yet.").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func cell(_ encounter: Encounter, _ label: String) -> some View {
        let variant = encounter.variant(label)
        if let party, !variant.slots.isEmpty {
            let budget = party.budget
            let experience = budget.experience(of: variant) { model.entry($0) }
            Button {
                model.startCombat(encounter: encounter, variantLabel: label, party: party)
            } label: {
                VStack(alignment: .leading) {
                    Text("\(experience) XP").monospacedDigit()
                    Text(budget.threat(forExperience: experience).rawValue.capitalized).font(.caption)
                    if model.inProgressSession(encounterID: encounter.id, variantLabel: label) != nil {
                        Label("In progress", systemImage: "circle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
            .buttonStyle(.borderless)
            .help("Run \(encounter.name) at \(label)")
        } else {
            Text(variant.slots.isEmpty ? "—" : "\(variant.slots.reduce(0) { $0 + $1.count }) creatures")
                .foregroundStyle(.secondary)
        }
    }
}

/// "Challenge points: 16 CP → 16–18 CP" (or "Party points: 12 points → Base" for Easier, Base and Harder), or why
/// the points can't be worked out.
struct ChallengePointsLine: View {
    let scenario: Scenario?
    let party: Party?
    @Environment(AppModel.self) private var model

    var body: some View {
        if let scenario, let party, let scheme = scenario.pointScheme {
            let counted = model.countingTableBuddies(party, in: scenario)
            if let pick = scenario.difficulty(for: counted) {
                LabeledContent(scheme == .challengePoints ? "Challenge points" : "Party points",
                               value: pick.pointsText + buddies(counted) + (pick.label.map { " → \($0)" } ?? ""))
                if !party.presentTableBuddies.isEmpty && counted.presentTableBuddies.isEmpty {
                    Text("The Guide adds no pregens to adventures for level 7 and up, so Table Buddies aren't counted.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            } else {
                Text("Set the scenario's levels (such as 3–6) to work out challenge points.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
    }

    /// " (Ezren at level 3)" when Table Buddies count.
    private func buddies(_ party: Party) -> String {
        let names = party.presentTableBuddies.map { "\($0.name) at level \($0.level ?? party.level)" }
        return names.isEmpty ? "" : " (\(names.joined(separator: ", ")))"
    }
}
