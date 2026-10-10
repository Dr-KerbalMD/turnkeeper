import BattleCards
import Bestiary
import CombatPadKit
import SwiftUI

/// The notes half of the pad: the battle card of whoever's turn it is (or the pinned combatant), then the
/// notes about that creature in this scenario and the encounter's notes, in a split the GM can resize.
struct CardPanel: View {
    let controller: BoardController
    @Environment(AppModel.self) private var model
    private var layout = StoredSplitLayout()
    @State private var isFlipped = false

    init(controller: BoardController) {
        self.controller = controller
    }

    var body: some View {
        VStack(spacing: 10) {
            header
            PaneStack(layout: layout.projectedValue, visible: visiblePanes, titles: titles) {
                cardArea
            } creatureNotes: {
                NotesEditor(text: creatureNoteBinding)
            } encounterNotes: {
                NotesEditor(text: encounterNotesBinding)
            }
        }
        .padding(12)
        // A new turn, or another strip tapped, shows the stat block again.
        .onChange(of: controller.cardCombatant?.id) { isFlipped = false }
    }

    @ViewBuilder
    private var cardArea: some View {
        if let combatant = controller.cardCombatant {
            card(for: combatant)
        } else {
            ContentUnavailableView("No one is acting", systemImage: "rectangle.portrait",
                                   description: Text("Begin combat, or tap a strip to see its card."))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    /// Creature notes show for creatures and hazards, not PCs.
    private var visiblePanes: Set<Int> {
        let isCreature = controller.cardCombatant.map { !$0.creatureKey.isEmpty && $0.kind != .playerCharacter }
        let hasCreature = (isCreature ?? false) && scenarioID != nil
        return hasCreature ? SplitLayout.allPanes : [SplitLayout.card, SplitLayout.encounterNotes]
    }

    private var titles: [Int: String] {
        let name = controller.cardCombatant.flatMap { controller.entry(for: $0)?.name } ?? ""
        return [SplitLayout.creatureNotes: "Creature Notes · \(name)", SplitLayout.encounterNotes: "Encounter Notes"]
    }

    private var encounter: Encounter? { controller.session.flatMap { model.encounter($0.encounterID) } }
    private var scenarioID: UUID? { encounter?.scenarioID }

    private var creatureNoteBinding: Binding<String> {
        let subject = controller.cardCombatant?.creatureKey ?? ""
        return Binding { [model, scenarioID] in
            scenarioID.map { model.library.creatureNote(scenarioID: $0, subject: subject).text } ?? ""
        } set: { [model, scenarioID] text in
            guard let scenarioID else { return }
            var note = model.library.creatureNote(scenarioID: scenarioID, subject: subject)
            note.text = text
            model.library.save(note)
        }
    }

    private var encounterNotesBinding: Binding<String> {
        Binding { [encounter] in encounter?.notes ?? "" } set: { [model, encounter] text in
            guard var edited = encounter.flatMap({ model.encounter($0.id) }) else { return }
            edited.notes = text
            model.library.save(edited)
        }
    }

    private var header: some View {
        HStack {
            if controller.pinnedID != nil {
                Button("Current Turn", systemImage: "arrow.uturn.backward") { controller.pinnedID = nil }
            }
            Spacer()
            ShowPlayersButton(entry: controller.cardCombatant.flatMap { controller.entry(for: $0) })
        }
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private func card(for combatant: Combatant) -> some View {
        if let creature = controller.creature(for: combatant) {
            VStack(spacing: 6) {
                FlippableCard(entry: controller.entry(for: combatant), isFlipped: $isFlipped) {
                    BattleCard(creature: creature, template: combatant.template, conditions: combatant.conditions)
                }
                MissingArtNote(key: combatant.creatureKey).foregroundStyle(.white.opacity(0.7))
            }
        } else {
            PlayerCard(combatant: combatant)
        }
    }
}

/// For quick PCs, without a linked sheet: the name and each condition's rules text.
private struct PlayerCard: View {
    let combatant: Combatant
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(combatant.name).font(.largeTitle.bold())
                if combatant.conditions.isEmpty {
                    Text("No conditions.").foregroundStyle(.secondary)
                }
                ForEach(combatant.conditions) { condition in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(ConditionLabel.short(condition)).font(.headline)
                        if let definition = model.bestiary.condition(condition.slug) {
                            Text(plainText(definition.text)).font(.callout)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private func plainText(_ text: RulesText) -> String {
        StatBlockText.plainText(text).replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "\n---", with: "")
    }
}

/// A notes text area on the board, saved as it's typed.
private struct NotesEditor: View {
    @Binding var text: String

    var body: some View {
        TextEditor(text: $text)
            .font(.callout)
            .scrollContentBackground(.hidden)
            .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
    }
}
