import CombatPadKit
import SwiftUI

/// What a card's links can open: the bestiary's glossary, how many popovers deep the view is, and the
/// card's presenter, so the creature's own abilities show its adjusted numbers.
struct GlossaryContext {
    /// Links work from the card and from its first popover, so they go two deep.
    static let maximumDepth = 2
    private static let scheme = "combatpad-glossary"
    private static let emptyBestiary = BestiaryStore()

    var bestiary = Self.emptyBestiary
    var depth = 0
    var presenter: StatBlockPresenter?

    var linksOpen: Bool { depth < Self.maximumDepth && bestiary.hasGlossary }

    /// The context for a popover opened from this one.
    var deeper: GlossaryContext {
        var context = self
        context.depth += 1
        return context
    }

    static func url(for target: String) -> URL? {
        URL(string: "\(scheme):\(target)")
    }

    func entry(for url: URL) -> GlossaryEntry? {
        guard url.scheme == Self.scheme else { return nil }
        return bestiary.glossaryEntry(String(url.absoluteString.dropFirst(Self.scheme.count + 1)))
    }

    func entry(_ id: String) -> GlossaryEntry? {
        bestiary.glossaryEntry(id)
    }

    /// The card's presenter for the creature's own entries; others are shown as written.
    func presenter(for entry: GlossaryEntry) -> StatBlockPresenter {
        if let presenter, entry.id.hasPrefix(presenter.creature.key + ".") { return presenter }
        return StatBlockPresenter(creature: Creature(key: "", name: "", game: presenter?.creature.game ?? .pathfinder))
    }
}

extension EnvironmentValues {
    @Entry var glossary = GlossaryContext()
}

/// A glossary entry in a popover: name, category, traits and text in the card's style. Its links open
/// another popover, one level deeper.
struct GlossaryPopover: View {
    let entry: GlossaryEntry
    let style: CardTextStyle
    @Environment(\.glossary) private var glossary

    var body: some View {
        ViewThatFits(in: .vertical) {
            content
            ScrollView { content }
        }
        .frame(width: 380)
        .frame(maxHeight: 520)
        .presentationBackground(style.paper)
        .presentationCompactAdaptation(.popover)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            ForEach(lines) { CardLineView(line: $0, style: style) }
        }
        .padding(14)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.cost == .none ? entry.name.uppercased() : entry.name.uppercased() + " ")
                    + ActionGlyph.text(entry.cost, size: style.size * 1.25, color: style.ink)
                Spacer(minLength: 8)
                Text(entry.category.uppercased())
            }
            .font(.pad(style.bold, size: style.size * 1.25))
            .foregroundStyle(style.ink)
            Rectangle().fill(style.ink).frame(height: 1)
        }
    }

    private var lines: [CardLine] {
        let text = RulesTextLines(presenter: glossary.presenter(for: entry)).lines(entry.text, isLimited: false)
            .map { CardLine($0.segments) }
        guard !entry.traits.isEmpty else { return text }
        let traits = entry.traits.map { slug -> [CardSegment] in
            let label = slug.replacingOccurrences(of: "-", with: " ")
            guard let target = entry.links.target(.trait, slug) else { return [.text(label)] }
            return [.link(label, target: target, emphasis: .plain)]
        }
        return [CardLine([.bold("Traits ")] + CardSegment.joined(traits))] + text
    }
}
