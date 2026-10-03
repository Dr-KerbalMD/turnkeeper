import CombatPadKit
import SwiftUI

/// A campaign's scenarios (with their encounters), parties and saved fights.
struct CampaignContentView: View {
    let campaign: Campaign
    @Environment(AppModel.self) private var model
    @State private var isAddingScenario = false

    var body: some View {
        @Bindable var model = model
        List(selection: $model.selection) {
            Section("Scenarios") {
                ForEach(model.library.scenarios(in: campaign.id)) { scenario in
                    ScenarioRows(scenario: scenario)
                }
                Button("Add Scenario", systemImage: "plus") { isAddingScenario = true }
            }
            Section("Parties") {
                ForEach(model.library.parties(in: campaign.id)) { party in
                    Label("\(party.name) · level \(party.level)", systemImage: "person.3")
                        .tag(PlannerSelection.party(party.id))
                        .contextMenu {
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                model.library.deleteParty(party.id)
                            }
                        }
                }
                Button("Add Party", systemImage: "plus") { model.addParty(to: campaign.id) }
            }
            SavedFightsSection(campaignID: campaign.id)
        }
        .navigationTitle(campaign.name)
        .sheet(isPresented: $isAddingScenario) { NewScenarioSheet(campaign: campaign) }
    }
}

/// A scenario and its encounters, indented under it.
private struct ScenarioRows: View {
    let scenario: Scenario
    @Environment(AppModel.self) private var model

    var body: some View {
        Label(scenario.name, systemImage: "map")
            .font(.headline)
            .tag(PlannerSelection.scenario(scenario.id))
            .contextMenu {
                Button("Add Encounter", systemImage: "plus") { model.addEncounter(to: scenario.id) }
                Button("Delete Scenario", systemImage: "trash", role: .destructive) {
                    model.library.deleteScenario(scenario.id)
                }
            }
        ForEach(model.library.encounters(in: scenario.id)) { encounter in
            Label(encounter.name, systemImage: "flame")
                .padding(.leading, 20)
                .tag(PlannerSelection.encounter(encounter.id))
                .contextMenu {
                    Button("Delete Encounter", systemImage: "trash", role: .destructive) {
                        model.library.deleteEncounter(encounter.id)
                    }
                }
        }
        Button("Add Encounter", systemImage: "plus") { model.addEncounter(to: scenario.id) }
            .padding(.leading, 20)
            .foregroundStyle(.secondary)
    }
}

/// Fights started earlier, to continue on this device.
private struct SavedFightsSection: View {
    let campaignID: UUID
    @Environment(AppModel.self) private var model

    var body: some View {
        let sessions = model.library.sessions(in: campaignID)
        if !sessions.isEmpty {
            Section("Saved fights") {
                ForEach(sessions) { session in
                    Button {
                        model.resumeCombat(session.id)
                    } label: {
                        LabeledContent(session.name, value: "round \(max(session.state.round, 1))")
                    }
                    .contextMenu {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            model.library.deleteSession(session.id)
                        }
                    }
                }
            }
        }
    }
}

/// Asks for a scenario's name and difficulty scheme.
private struct NewScenarioSheet: View {
    let campaign: Campaign
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var scheme = VariantScheme.single
    @State private var labels = ""

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name, prompt: Text("#7-03: The Sunken Vault"))
                Picker("Difficulty variants", selection: $scheme) {
                    Text("Pathfinder Society (challenge points)").tag(VariantScheme.pathfinderSociety)
                    Text("Starfinder Society (easier/base/harder)").tag(VariantScheme.starfinderSociety)
                    Text("One version").tag(VariantScheme.single)
                }
                TextField("Variant labels, comma separated", text: $labels)
                Text("Challenge-point brackets differ between scenarios; edit them to match the one you're running.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .formStyle(.grouped)
            .navigationTitle("New Scenario")
            .onAppear { scheme = campaign.game == .starfinder ? .starfinderSociety : .single }
            .onChange(of: scheme, initial: true) { labels = scheme.labels.joined(separator: ", ") }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Add", action: add) }
            }
        }
        .frame(minWidth: 420, minHeight: 280)
    }

    private func add() {
        let parsed = labels.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        model.addScenario(to: campaign.id, name: name.isEmpty ? "New scenario" : name, labels: parsed)
        dismiss()
    }
}
