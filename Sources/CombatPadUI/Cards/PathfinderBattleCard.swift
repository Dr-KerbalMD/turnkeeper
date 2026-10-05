import CombatPadKit
import SwiftUI

/// A battle card in the style of the Pathfinder Bestiary Battle Cards: parchment, a condensed title with the
/// level at the right, colored trait boxes, and the stat block in ruled sections.
struct PathfinderBattleCard: View {
    let content: CardContent
    var textSize: CGFloat = 15
    /// Off for snapshots, which need the whole card laid out at once.
    var scrolls = true

    var body: some View {
        Scrollable(scrolls: scrolls) {
            VStack(alignment: .leading, spacing: 4) {
                header
                TraitChips(traits: content.traits, links: content.links, game: .pathfinder, style: style)
                lines(content.hazard)
                lines(content.senses + content.statistics + content.interaction)
                Rule()
                lines(content.defense)
                if !content.hitPoints.isEmpty { CardLineView(line: CardLine(content.hitPoints), style: style) }
                lines(content.defensive)
                Rule()
                lines(content.offense + content.offensive)
                SourceLine(text: content.source, color: Color(hex: 0x231A12, opacity: 0.55))
            }
            .padding(20)
        }
        .background {
            Parchment()
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay { RoundedRectangle(cornerRadius: 12).strokeBorder(Color(hex: 0x6B4A2B), lineWidth: 3) }
    }

    private var header: some View {
        VStack(spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(content.name.uppercased())
                    .font(.custom(FontName.condensedBold, size: textSize * 1.9))
                Spacer(minLength: 8)
                TemplateBadge(template: content.template, color: Color(hex: 0x6B1A12))
                Text(content.levelLabel)
                    .font(.custom(FontName.condensedBold, size: textSize * 1.9))
            }
            .foregroundStyle(Color(hex: 0x231A12))
            Rectangle().fill(Color(hex: 0x231A12)).frame(height: 1.5)
        }
    }

    private func lines(_ lines: [CardLine]) -> some View {
        ForEach(lines) { CardLineView(line: $0, style: style) }
    }

    private var style: CardTextStyle {
        CardTextStyle(body: FontName.condensed, bold: FontName.condensedBold, italic: FontName.condensedItalic,
                      size: textSize, ink: Color(hex: 0x231A12), paper: Color(hex: 0xF1E3C1),
                      worse: Color(hex: 0xB00020), better: Color(hex: 0x1B6E20))
    }
}

/// The thin dark rule between stat-block sections.
private struct Rule: View {
    var body: some View {
        Rectangle().fill(Color(hex: 0x231A12)).frame(height: 1).padding(.vertical, 2)
    }
}

/// Aged paper: a warm gradient, darker toward the scorched edges.
struct Parchment: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0xF4E8CC), Color(hex: 0xE9D7AE)], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [.clear, Color(hex: 0x8A5A2B, opacity: 0.35)],
                           center: .center, startRadius: 220, endRadius: 520)
        }
    }
}

/// "ELITE" or "WEAK" next to the level, when a template applies.
struct TemplateBadge: View {
    let template: CreatureTemplate
    let color: Color

    var body: some View {
        if template != .normal {
            Text(template.rawValue.uppercased())
                .font(.custom(FontName.condensedBold, size: 12))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(template == .elite ? color : Color(hex: 0x4A5A6A), in: Capsule())
        }
    }
}

/// The book a creature comes from, small and quiet at the foot of the card.
struct SourceLine: View {
    let text: String
    let color: Color

    var body: some View {
        if !text.isEmpty {
            Text(text)
                .font(.custom(FontName.condensedItalic, size: 11))
                .foregroundStyle(color)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 6)
        }
    }
}
