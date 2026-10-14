import BattleCards
import Bestiary
import TurnkeeperKit
import SwiftUI

/// A creature's battle card on its own, from the bestiary browser, an encounter or the party (a PC's `pc.` key).
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
                    VStack(spacing: 8) {
                        CreatureBattleCard(entry: model.entry(key), front: BattleCard(
                            creature: creature, template: template, conditions: conditions))
                        MissingArtNote(key: key)
                    }
                    .padding()
                } else if isPlayerCharacter {
                    ContentUnavailableView("No battle card", systemImage: "person.crop.rectangle",
                                           description: Text("Link this player to Demiplane to import their sheet."))
                } else {
                    ContentUnavailableView("Not in the bestiary", systemImage: "questionmark")
                }
            }
            .navigationTitle(model.entry(key)?.name ?? "")
            .acceptsArtwork(for: key, model: model)
            .toolbar { ArtworkControls(key: key) }
            .toolbar {
                if !isPlayerCharacter {
                    ToolbarItem {
                        Picker("Template", selection: $template) {
                            Text("Weak").tag(CreatureTemplate.weak)
                            Text("Normal").tag(CreatureTemplate.normal)
                            Text("Elite").tag(CreatureTemplate.elite)
                        }
                        .pickerStyle(.segmented)
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
        .battleCardFullScreenHost()
        .frame(minWidth: 600, minHeight: 760)
    }

    /// PCs have no Weak or Elite templates.
    private var isPlayerCharacter: Bool { PlayerCharacter.isKey(key) }
}
