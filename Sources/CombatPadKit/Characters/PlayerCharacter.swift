import Foundation

/// The parts of a player character's sheet that a creature doesn't have.
public struct PlayerDetails: Codable, Sendable, Hashable {
    public var ancestry: String
    public var heritage: String
    public var background: String
    public var className: String
    /// Zero when the sheet shows none.
    public var classDC: Int
    public var feats: [String]
    public var classFeatures: [String]

    public init(ancestry: String = "", heritage: String = "", background: String = "", className: String = "") {
        self.ancestry = ancestry
        self.heritage = heritage
        self.background = background
        self.className = className
        classDC = 0
        feats = []
        classFeatures = []
    }
}

/// Where a linked PC's sheet came from.
public struct CharacterLink: Codable, Sendable, Hashable {
    public enum Source: String, Codable, Sendable {
        case demiplane
    }

    public var source: Source
    /// The character's ID at the source, such as a Demiplane character UUID.
    public var characterID: String
    public var game: Game
    /// The source's revision of the sheet, which changes whenever the character does.
    public var revision: String
    public var fetchedAt: Date
    /// How many of the sheet's spells, abilities and items lead to the glossary, out of how many.
    public var linkedNames: Int
    public var totalNames: Int

    public init(source: Source, characterID: String, game: Game, revision: String = "", fetchedAt: Date = Date()) {
        self.source = source
        self.characterID = characterID
        self.game = game
        self.revision = revision
        self.fetchedAt = fetchedAt
        linkedNames = 0
        totalNames = 0
    }
}

/// Player characters on the board: a linked PC's card is its sheet under the key `pc.<member id>`.
public enum PlayerCharacter {
    public static let keyPrefix = "pc."

    public static func key(for member: PartyMember) -> String {
        key(memberID: member.id)
    }

    public static func key(memberID: UUID) -> String {
        keyPrefix + memberID.uuidString
    }

    public static func isKey(_ key: String) -> Bool {
        key.hasPrefix(keyPrefix)
    }

    /// The member a `pc.` key points at.
    public static func memberID(fromKey key: String) -> UUID? {
        isKey(key) ? UUID(uuidString: String(key.dropFirst(keyPrefix.count))) : nil
    }

    /// The card for a linked member: the sheet under the member's key and name, with the max HP the GM
    /// typed (zero, so no HP line, when there is none). Nil for a quick PC.
    public static func creature(for member: PartyMember) -> Creature? {
        guard var creature = member.sheet else { return nil }
        creature.key = key(for: member)
        creature.name = member.name
        creature.kind = .character
        creature.defenses.hitPoints = member.maxHitPoints ?? 0
        return creature
    }
}
