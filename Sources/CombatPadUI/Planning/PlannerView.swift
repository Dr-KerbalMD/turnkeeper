import CombatPadKit
import SwiftUI

/// Campaigns on the left, the selected campaign's scenarios and parties in the middle, and the selected
/// scenario, encounter or party on the right.
struct PlannerView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationSplitView {
            CampaignSidebar()
                .navigationSplitViewColumnWidth(min: 200, ideal: 240)
        } content: {
            if let campaign = model.selectedCampaign {
                CampaignContentView(campaign: campaign)
                    .navigationSplitViewColumnWidth(min: 260, ideal: 320)
            } else {
                ContentUnavailableView("No campaign", systemImage: "book.closed",
                                       description: Text("Add a campaign to start planning."))
            }
        } detail: {
            PlannerDetail()
        }
        .alert("A fight is in progress for this encounter.", isPresented: pendingBinding,
               presenting: model.pendingPlanChange) { pending in
            Button("Change and Reset", role: .destructive) { model.confirm(pending) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Changing its creatures or events will reset that fight.")
        }
    }

    private var pendingBinding: Binding<Bool> {
        Binding(get: { model.pendingPlanChange != nil }, set: { if !$0 { model.pendingPlanChange = nil } })
    }
}

/// The detail column for the current selection.
private struct PlannerDetail: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        switch model.selection {
        case let .scenario(id):
            if let scenario = model.scenario(id) { ScenarioView(scenario: scenario) } else { empty }
        case let .encounter(id):
            if let encounter = model.encounter(id) { EncounterEditorView(encounter: encounter) } else { empty }
        case let .handout(id):
            if let handout = model.handout(id) { HandoutView(handout: handout) } else { empty }
        case let .party(id):
            if let party = model.party(id) { PartyEditorView(party: party) } else { empty }
        case nil:
            empty
        }
    }

    private var empty: some View {
        ContentUnavailableView("Nothing selected", systemImage: "list.bullet.rectangle",
                               description: Text("Choose a scenario, encounter or party."))
    }
}
