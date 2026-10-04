import CombatPadKit
import SwiftUI

/// A creature's battle card on its own, from the bestiary browser, with the player view one tap away.
struct CreaturePreview: View {
    let key: String
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var template: CreatureTemplate
    /// Conditions shown on the card, such as a planned creature's starting conditions.
    let conditions: [AppliedCondition]

    /// - Parameter template: the template the card opens with, such as the encounter slot's.
    init(key: String, template: CreatureTemplate = .normal, conditions: [AppliedCondition] = []) {
        self.key = key
        self.conditions = conditions
        _template = State(initialValue: template)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let creature = model.creature(key) {
                    BattleCard(creature: creature, template: template, conditions: conditions)
                        .padding()
                } else {
                    ContentUnavailableView("Not in the bestiary", systemImage: "questionmark")
                }
            }
            .navigationTitle(model.entry(key)?.name ?? "")
            .toolbar {
                ToolbarItem {
                    Picker("Template", selection: $template) {
                        Text("Weak").tag(CreatureTemplate.weak)
                        Text("Normal").tag(CreatureTemplate.normal)
                        Text("Elite").tag(CreatureTemplate.elite)
                    }
                    .pickerStyle(.segmented)
                }
                ToolbarItem { ShowPlayersButton(entry: model.entry(key)) }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .frame(minWidth: 600, minHeight: 760)
    }
}

/// The player view, full screen. Tap to close.
struct PlayerViewSheet: View {
    let entry: BestiaryIndexEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        CardBackView(entry: entry)
            .onTapGesture { dismiss() }
            #if os(iOS)
            .statusBarHidden()
            .persistentSystemOverlays(.hidden)
            #else
            .frame(minWidth: 640, idealWidth: 760, minHeight: 900, idealHeight: 1100)
            #endif
    }
}
