import Foundation

/// A spellcasting entry, such as "Divine Innate Spells DC 27, attack +17".
public struct Spellcasting: Codable, Sendable, Hashable {
    public var name: String
    /// The spell DC. Zero when the entry has none, such as for rituals.
    public var difficultyClass: Int
    /// The spell attack modifier. Zero when the entry has none.
    public var attack: Int
    /// Ranks from highest to lowest, with cantrips and constant spells last as in the books.
    public var ranks: [SpellRank]

    public init(name: String, difficultyClass: Int, attack: Int, ranks: [SpellRank]) {
        self.name = name
        self.difficultyClass = difficultyClass
        self.attack = attack
        self.ranks = ranks
    }
}

public struct SpellRank: Codable, Sendable, Hashable {
    public enum Kind: String, Codable, Sendable {
        case ranked
        case cantrips
        case constant
    }

    public var kind: Kind
    /// The rank, or the heightened rank for cantrips and constant spells.
    public var rank: Int
    /// Shown after the rank, such as "3 slots".
    public var note: String
    public var spells: [SpellEntry]

    public init(kind: Kind, rank: Int, spells: [SpellEntry], note: String = "") {
        self.kind = kind
        self.rank = rank
        self.spells = spells
        self.note = note
    }
}

public struct SpellEntry: Codable, Sendable, Hashable {
    public var name: String
    /// Text shown after the name in parentheses, such as "×3" or "at will".
    public var note: String

    public init(name: String, note: String = "") {
        self.name = name
        self.note = note
    }
}
