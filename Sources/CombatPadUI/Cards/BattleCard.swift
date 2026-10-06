import CombatPadKit
import SwiftUI

/// A creature's battle card in its game's style, with the template and conditions applied.
struct BattleCard: View {
    let creature: Creature
    var template: CreatureTemplate = .normal
    var conditions: [AppliedCondition] = []
    var textSize: CGFloat = 15
    var scrolls = true

    @Environment(\.glossary) private var glossary

    var body: some View {
        let presenter = StatBlockPresenter(creature: creature, template: template, conditions: conditions)
        let content = CardContent(presenter: presenter)
        Group {
            if creature.game == .starfinder {
                StarfinderBattleCard(content: content, textSize: textSize, scrolls: scrolls)
            } else {
                PathfinderBattleCard(content: content, textSize: textSize, scrolls: scrolls)
            }
        }
        .environment(\.glossary, cardGlossary(presenter))
    }

    private func cardGlossary(_ presenter: StatBlockPresenter) -> GlossaryContext {
        var context = glossary
        context.presenter = presenter
        return context
    }
}

/// Wraps content in a scroll view, or not.
struct Scrollable<Content: View>: View {
    let scrolls: Bool
    @ViewBuilder let content: Content

    var body: some View {
        if scrolls {
            ScrollView { content }
        } else {
            content
        }
    }
}
