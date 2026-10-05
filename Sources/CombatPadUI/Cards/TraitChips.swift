import CombatPadKit
import SwiftUI

/// The trait boxes under a card's title: rarity, size and other traits, colored as in the books. A trait
/// the creature links opens its glossary entry.
struct TraitChips: View {
    let traits: TraitLine
    let links: LinkTable
    let game: Game
    let style: CardTextStyle

    var body: some View {
        FlowLayout(spacing: 3) {
            ForEach(chips, id: \.label) { chip in
                TraitChip(chip: chip, edge: edge, edgeWidth: game == .pathfinder ? 1 : 0.5, style: style)
            }
        }
    }

    private var chips: [Chip] {
        var chips: [Chip] = []
        if let rarity = Self.rarityColors[traits.rarity] { chips.append(Chip(label: traits.rarity, color: rarity)) }
        chips.append(Chip(label: traits.size, color: Self.sizeColor))
        chips += traits.traits.map { slug in
            Chip(label: slug.replacingOccurrences(of: "-", with: " "), color: traitColor,
                 target: links.target(.trait, slug) ?? "")
        }
        return chips
    }

    private var traitColor: Color { game == .pathfinder ? Color(hex: 0x5D0000) : Color(hex: 0x0B5566) }
    private var edge: Color { game == .pathfinder ? Color(hex: 0xD8C38A) : Color(hex: 0x27C8F2, opacity: 0.6) }

    private static let sizeColor = Color(hex: 0x478C42)
    private static let rarityColors = [
        "uncommon": Color(hex: 0x98513D), "rare": Color(hex: 0x002664), "unique": Color(hex: 0x54166E)
    ]
}

/// One trait box: its label, color, and the glossary entry it opens, if any.
private struct Chip {
    var label: String
    var color: Color
    var target = ""
}

/// A trait box, a button when it leads to the glossary.
private struct TraitChip: View {
    let chip: Chip
    let edge: Color
    let edgeWidth: CGFloat
    let style: CardTextStyle
    @Environment(\.glossary) private var glossary
    @State private var shownEntry: GlossaryEntry?

    var body: some View {
        if chip.target.isEmpty || !glossary.linksOpen {
            label
        } else {
            Button { shownEntry = glossary.entry(chip.target) } label: { label }
                .buttonStyle(.plain)
                .popover(item: $shownEntry) { entry in
                    GlossaryPopover(entry: entry, style: style).environment(\.glossary, glossary.deeper)
                }
        }
    }

    private var label: some View {
        Text(chip.label.uppercased())
            .font(.custom(FontName.condensedBold, size: 11))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(chip.color)
            .overlay { Rectangle().stroke(edge, lineWidth: edgeWidth) }
    }
}

/// Lays out views left to right, wrapping to new rows.
struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var top = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var left = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: left, y: top), proposal: ProposedViewSize(size))
                left += size.width + spacing
            }
            top += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !rows[rows.count - 1].indices.isEmpty, rows[rows.count - 1].width + spacing + size.width > width {
                rows.append(Row())
            }
            let gap = rows[rows.count - 1].indices.isEmpty ? 0 : spacing
            rows[rows.count - 1].indices.append(index)
            rows[rows.count - 1].width += gap + size.width
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
        }
        return rows
    }
}
