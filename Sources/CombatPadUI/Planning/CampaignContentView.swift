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
        .renamableTitle(campaign.name, rename: rename)
        .sheet(isPresented: $isAddingScenario) { NewScenarioSheet(campaign: campaign) }
    }

    private func rename(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, var current = model.library.campaigns.first(where: { $0.id == campaign.id })
        else { return }
        current.name = trimmed
        model.library.save(current)
    }
}

private extension View {
    /// On the iPad the title can be tapped to rename; on the Mac, Rename… is in the sidebar's menu.
    @ViewBuilder
    func renamableTitle(_ title: String, rename: @escaping (String) -> Void) -> some View {
        #if os(iOS)
        navigationTitle(Binding(get: { title }, set: rename))
            .toolbarRole(.editor)
        #else
        navigationTitle(title)
        #endif
    }
}

/// A scenario and its encounters, indented under it.
private struct ScenarioRows: View {
    let scenario: Scenario
    @Environment(AppModel.self) private var model
    /// Collapsed scenarios on this device, as comma-separated IDs. New scenarios start expanded.
    @AppStorage("collapsedScenarios") private var collapsed = ""

    var body: some View {
        HStack {
            Button {
                toggle()
            } label: {
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 20)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(isExpanded ? "Collapse \(scenario.name)" : "Expand \(scenario.name)")
            Label(scenario.name, systemImage: "map").font(.headline)
            Spacer()
            if !isExpanded {
                Text("\(model.library.encounters(in: scenario.id).count)").foregroundStyle(.secondary)
            }
        }
        .tag(PlannerSelection.scenario(scenario.id))
        .contextMenu {
            Button("Add Encounter", systemImage: "plus") { model.addEncounter(to: scenario.id) }
            Button("Delete Scenario", systemImage: "trash", role: .destructive) {
                model.library.deleteScenario(scenario.id)
            }
        }
        if isExpanded { contents }
    }

    @ViewBuilder
    private var contents: some View {
        ForEach(model.library.encounters(in: scenario.id)) { encounter in
            Label(encounter.name, systemImage: "flame")
                .padding(.leading, 28)
                .tag(PlannerSelection.encounter(encounter.id))
                .contextMenu {
                    Button("Delete Encounter", systemImage: "trash", role: .destructive) {
                        model.library.deleteEncounter(encounter.id)
                    }
                }
        }
        Button("Add Encounter", systemImage: "plus") { model.addEncounter(to: scenario.id) }
            .padding(.leading, 28)
            .foregroundStyle(.secondary)
    }

    private var collapsedIDs: Set<String> { Set(collapsed.split(separator: ",").map(String.init)) }
    private var isExpanded: Bool { !collapsedIDs.contains(scenario.id.uuidString) }

    private func toggle() {
        var ids = collapsedIDs
        if isExpanded { ids.insert(scenario.id.uuidString) } else { ids.remove(scenario.id.uuidString) }
        withAnimation { collapsed = ids.sorted().joined(separator: ",") }
    }
}

/// Fights to continue, and finished ones to look back at.
private struct SavedFightsSection: View {
    let campaignID: UUID
    @Environment(AppModel.self) private var model

    var body: some View {
        let sessions = model.library.sessions(in: campaignID)
        let unfinished = sessions.filter { !$0.isFinished }
        let finished = sessions.filter(\.isFinished).prefix(10)
        if !unfinished.isEmpty {
            Section("Fights in progress") {
                ForEach(unfinished) { session in row(session, detail: "round \(max(session.state.round, 1))") }
            }
        }
        if !finished.isEmpty {
            Section("Finished fights") {
                ForEach(Array(finished)) { session in row(session, detail: "over") }
            }
        }
    }

    private func row(_ session: CombatSession, detail: String) -> some View {
        Button {
            model.resumeCombat(session.id)
        } label: {
            LabeledContent(session.name, value: detail)
        }
        .contextMenu {
            Button("Delete", systemImage: "trash", role: .destructive) { model.library.deleteSession(session.id) }
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
                TextField("Name", text: $name, prompt: Text("#7-03: The Sunken Vault")).titleEntry()
                Picker("Difficulty variants", selection: $scheme) {
                    ForEach(VariantScheme.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                TextField("Variant labels, comma separated", text: $labels)
                Text("The labels can be edited to match the scenario being run.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .formStyle(.grouped)
            .navigationTitle("New Scenario")
            .onAppear { scheme = .easierBaseHarder }
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
