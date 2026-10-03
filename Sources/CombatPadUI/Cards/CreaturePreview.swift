import CombatPadKit
import SwiftUI

/// A creature's battle card on its own, from the bestiary browser, with the player view one tap away.
struct CreaturePreview: View {
    let key: String
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var template = CreatureTemplate.normal

    var body: some View {
        NavigationStack {
            Group {
                if let creature = model.bestiary.creature(key) {
                    BattleCard(creature: creature, template: template)
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
            .frame(minWidth: 500, minHeight: 720)
    }
}
