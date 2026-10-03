import CombatPadKit
import SwiftUI

/// The notes half of the pad: the battle card of whoever's turn it is (or the pinned combatant), and the
/// encounter's notes below.
struct CardPanel: View {
    let controller: BoardController
    @Environment(AppModel.self) private var model
    @State private var notesExpanded = true

    var body: some View {
        VStack(spacing: 10) {
            header
            Group {
                if let combatant = controller.cardCombatant {
                    card(for: combatant)
                } else {
                    ContentUnavailableView("No one is acting", systemImage: "rectangle.portrait",
                                           description: Text("Begin combat, or tap a strip to see its card."))
                        .foregroundStyle(.white)
                }
            }
            .frame(maxHeight: .infinity)
            NotesPanel(controller: controller, isExpanded: $notesExpanded)
        }
        .padding(12)
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
            BattleCard(creature: creature, template: combatant.template, conditions: combatant.conditions)
        } else {
            PlayerCard(combatant: combatant)
        }
    }
}

/// For PCs and custom NPCs: the name and each condition's rules text.
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
        text.markup.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "\n---", with: "")
    }
}

/// The encounter's planning notes, read-only, and this fight's scratch notes, like the pad's write-on area.
private struct NotesPanel: View {
    let controller: BoardController
    @Binding var isExpanded: Bool
    @Environment(AppModel.self) private var model

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: 6) {
                if let notes = encounterNotes, !notes.isEmpty {
                    Text(notes).font(.callout).foregroundStyle(.secondary)
                }
                TextEditor(text: scratchBinding)
                    .font(.callout)
                    .frame(minHeight: 70, maxHeight: 140)
                    .scrollContentBackground(.hidden)
                    .background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
            }
        } label: {
            Label("Notes", systemImage: "note.text").font(.headline)
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    }

    private var encounterNotes: String? {
        controller.session.flatMap { model.encounter($0.encounterID)?.notes }
    }

    private var scratchBinding: Binding<String> {
        Binding(get: { controller.session?.scratchNotes ?? "" },
                set: { text in
                    guard var session = controller.session else { return }
                    session.scratchNotes = text
                    model.library.save(session)
                })
    }
}
