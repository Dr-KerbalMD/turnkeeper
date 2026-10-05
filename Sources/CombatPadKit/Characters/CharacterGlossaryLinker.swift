import Foundation

/// Where a player character's names are looked up: the bundled bestiary's glossary.
public protocol GlossarySource: Sendable {
    func glossaryID(game: Game, kind: GlossaryIndex.Kind, name: String) -> String?
    func glossaryEntry(_ id: String) -> GlossaryEntry?
}

extension BestiaryStore: GlossarySource {}

/// A sheet with its glossary links, and how many of its names were linked, out of how many.
public struct LinkedSheet: Sendable {
    public var sheet: Creature
    public var linkedNames: Int
    public var totalNames: Int
}

/// Links an imported sheet's spells, abilities, feats, items and traits to the glossary by name, for the
/// character's game. A name without a match stays plain text. An ability whose entry has rules text shows
/// that text instead of the sheet's.
public struct CharacterGlossaryLinker {
    public let glossary: any GlossarySource

    public init(glossary: any GlossarySource) {
        self.glossary = glossary
    }

    public func link(_ sheet: Creature) -> LinkedSheet {
        var names = NameLinker(glossary: glossary, game: sheet.game)
        var sheet = sheet
        for name in sheet.spellcasting.flatMap(\.ranks).flatMap(\.spells).map(\.name) {
            names.add(.spell, name, as: .spell)
        }
        for name in sheet.items + sheet.strikes.map(\.name) {
            names.add(.item, name, as: .item)
        }
        for name in (sheet.player?.feats ?? []) + (sheet.player?.classFeatures ?? []) {
            names.add(.ability, name, as: .ability)
        }
        for index in sheet.abilities.indices {
            guard let id = names.add(.ability, sheet.abilities[index].name, as: .ability),
                  let text = glossary.glossaryEntry(id)?.text, !text.isEmpty else { continue }
            sheet.abilities[index].text = text
        }
        let traits = sheet.traits.traits + sheet.strikes.flatMap(\.traits) + sheet.abilities.flatMap(\.traits)
        Set(traits).forEach { names.addTrait($0) }
        sheet.links = names.links
        return LinkedSheet(sheet: sheet, linkedNames: names.linked, totalNames: names.total)
    }
}

/// The links made so far, counting each distinct name once.
private struct NameLinker {
    let glossary: any GlossarySource
    let game: Game
    var links = LinkTable()
    var linked = 0
    var total = 0
    private var seen = Set<String>()

    init(glossary: any GlossarySource, game: Game) {
        self.glossary = glossary
        self.game = game
    }

    @discardableResult
    mutating func add(_ kind: LinkTable.Kind, _ name: String, as indexKind: GlossaryIndex.Kind) -> String? {
        guard seen.insert("\(kind.rawValue):\(name)").inserted else { return links.target(kind, name) }
        total += 1
        guard let id = glossary.glossaryID(game: game, kind: indexKind, name: name) else { return nil }
        linked += 1
        links.add(kind, name, target: id)
        return id
    }

    /// A trait slug such as `thrown-10-ft` or `deadly-d8`, by its longest leading words with an entry.
    mutating func addTrait(_ slug: String) {
        let words = slug.split(separator: "-").map(String.init)
        for count in (1...max(words.count, 1)).reversed() {
            let name = words.prefix(count).joined(separator: " ")
            if let id = glossary.glossaryID(game: game, kind: .trait, name: name) {
                links.add(.trait, slug, target: id)
                return
            }
        }
    }
}
