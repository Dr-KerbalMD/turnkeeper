import Foundation

/// A condition as the rules define it, imported from the system's condition packs.
public struct ConditionDefinition: Codable, Sendable, Identifiable, Hashable {
    public var slug: String
    public var name: String
    /// The games that have this condition. Starfinder has every Pathfinder condition plus a few.
    public var games: [Game]
    /// Whether the condition carries a number, such as frightened 2.
    public var isValued: Bool
    public var text: RulesText

    public var id: String { slug }

    public init(slug: String, name: String, games: [Game], isValued: Bool, text: RulesText) {
        self.slug = slug
        self.name = name
        self.games = games
        self.isValued = isValued
        self.text = text
    }
}
