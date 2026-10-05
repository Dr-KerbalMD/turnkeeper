import Foundation

/// Glossary IDs by name, for linking a player character's spells, abilities, items and traits, which come
/// from outside Foundry and so have only names. Keys are `<game>:<kind>:<normalized name>`.
public struct GlossaryIndex: Codable, Sendable, Hashable {
    public enum Kind: String, Sendable, CaseIterable {
        case spell
        /// Feats, class features, actions and heritages.
        case ability
        case item
        case trait
    }

    private var ids: [String: String]

    public init() {
        ids = [:]
    }

    public init(from decoder: Decoder) throws {
        ids = try decoder.singleValueContainer().decode([String: String].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(ids)
    }

    public var count: Int { ids.count }

    /// The glossary ID for a name, or nil when nothing of that kind has the name.
    public func id(game: Game, kind: Kind, name: String) -> String? {
        ids[Self.key(game, kind, name)]
    }

    /// Records a name. The first ID recorded for a name wins, so add preferred documents first.
    public mutating func add(game: Game, kind: Kind, name: String, id: String) {
        let key = Self.key(game, kind, name)
        if ids[key] == nil { ids[key] = id }
    }

    /// Lowercase, without apostrophes, with other punctuation as single spaces: "Healing Potion, Moderate"
    /// and "Healing Potion (Moderate)" both become "healing potion moderate".
    public static func normalize(_ name: String) -> String {
        let folded = name.lowercased().replacingOccurrences(of: "[’'`]", with: "", options: .regularExpression)
        return folded.split { !$0.isLetter && !$0.isNumber }.joined(separator: " ")
    }

    private static func key(_ game: Game, _ kind: Kind, _ name: String) -> String {
        "\(game.rawValue):\(kind.rawValue):\(normalize(name))"
    }
}
