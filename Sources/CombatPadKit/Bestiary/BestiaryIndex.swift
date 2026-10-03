import Foundation

/// The summary of one bestiary entry, enough to browse, search and budget without loading stat blocks.
public struct BestiaryIndexEntry: Codable, Sendable, Identifiable, Hashable {
    public var key: String
    public var name: String
    public var game: Game
    public var kind: CreatureKind
    public var level: Int
    public var traits: TraitLine
    public var source: Source
    public var art: ArtReference
    /// The initiative modifier: Perception, or Stealth for most hazards.
    public var initiativeModifier: Int

    public var id: String { key }

    public init(creature: Creature) {
        initiativeModifier = creature.initiativeModifier
        key = creature.key
        name = creature.name
        game = creature.game
        kind = creature.kind
        level = creature.level
        traits = creature.traits
        source = creature.source
        art = creature.art
    }

    /// The pack file that holds the full stat block, `<game>.<pack>`.
    public var packFile: String { "\(game.rawValue).\(source.pack)" }
}

/// The contents of `Generated/Bestiary/index.json`.
public struct BestiaryIndex: Codable, Sendable {
    /// The pf2e repository commit the import was made from.
    public var sourceRevision: String
    public var entries: [BestiaryIndexEntry]

    public init(sourceRevision: String, entries: [BestiaryIndexEntry]) {
        self.sourceRevision = sourceRevision
        self.entries = entries
    }
}
