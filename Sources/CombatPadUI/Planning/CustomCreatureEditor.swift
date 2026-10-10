import BattleCards
import Bestiary
import CombatPadKit
import SwiftUI

/// Edits a custom creature: the form on the left, its battle card on the right, updating as you type.
/// Cancel discards the edits; Done saves them.
struct CustomCreatureEditor: View {
    let original: CustomCreature
    let save: (CustomCreature) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CreatureDraft
    @State private var isShowingCard = false

    init(custom: CustomCreature, save: @escaping (CustomCreature) -> Void) {
        original = custom
        self.save = save
        _draft = State(initialValue: CreatureDraft(custom.creature))
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                let isWide = geometry.size.width > 900
                HStack(spacing: 0) {
                    if isWide || !isShowingCard {
                        VStack(spacing: 0) {
                            replaceBar
                            CreatureDraftForm(draft: $draft)
                        }
                        .frame(width: isWide ? geometry.size.width * 0.5 : geometry.size.width)
                    }
                    if isWide || isShowingCard {
                        BattleCard(creature: preview).padding()
                    }
                }
                .toolbar {
                    if !isWide {
                        ToolbarItem {
                            Toggle(isOn: $isShowingCard) { Label("Card", systemImage: "rectangle.portrait") }
                        }
                    }
                }
            }
            .navigationTitle(draft.name.isEmpty ? "New Creature" : draft.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        var edited = original
                        edited.creature = preview
                        save(edited)
                        dismiss()
                    }
                    .disabled(draft.name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .frame(minWidth: 760, minHeight: 760)
    }

    private var preview: Creature { draft.creature(from: original.creature) }

    /// Replaces the draft only; Cancel still keeps the creature as it was. In the page rather than the
    /// toolbar, since iOS ignores a paste button it can't see in full.
    private var replaceBar: some View {
        HStack {
            PasteButton(supportedContentTypes: StatBlockPasteboard.acceptedTypes) { replace(from: $0) }
                .labelStyle(.titleAndIcon)
            Text("Replace with a stat block copied from Pluck").font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private func replace(from providers: [NSItemProvider]) {
        Task {
            guard let block = await StatBlockPasteboard.blocks(from: providers).first else { return }
            let conversion = StatBlockConverter.convert(block, key: original.key, game: original.creature.game)
            draft = CreatureDraft(conversion.creature)
        }
    }
}
