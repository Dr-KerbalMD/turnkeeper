import Foundation

/// Where the linked words of a stat block or glossary entry lead: each kind of word and its shown text map
/// to a glossary ID.
public struct LinkTable: Codable, Sendable, Hashable {
    public enum Kind: String, Sendable {
        case spell
        case item
        /// A Strike's extra effect, such as "Grab".
        case effect
        case trait
        /// A player character's action, reaction, feat or class feature.
        case ability
    }

    private var targets: [String: String]

    public init() {
        targets = [:]
    }

    public init(from decoder: Decoder) throws {
        targets = try decoder.singleValueContainer().decode([String: String].self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(targets)
    }

    public var isEmpty: Bool { targets.isEmpty }

    /// Every glossary ID in the table, sorted.
    public var allTargets: [String] { Set(targets.values).sorted() }

    /// The glossary ID for a word, such as the spell "fireball" or the trait "reach-10".
    public func target(_ kind: Kind, _ text: String) -> String? {
        targets[Self.key(kind, text)]
    }

    public mutating func add(_ kind: Kind, _ text: String, target: String) {
        targets[Self.key(kind, text)] = target
    }

    private static func key(_ kind: Kind, _ text: String) -> String {
        "\(kind.rawValue):\(text)"
    }
}

/// A spell, item, condition, action, trait or ability that a card links to.
public struct GlossaryEntry: Codable, Sendable, Hashable, Identifiable {
    /// `<system>.<pack>.<_id>` for compendium documents, `<creature key>.<item _id>` for a creature's own
    /// copy, and `trait.<game>.<slug>` for traits.
    public var id: String
    public var name: String
    /// "Spell 3", "Cantrip 1", "Item 5", "Condition", "Trait" and the like.
    public var category: String
    public var cost: ActionCost
    public var traits: [String]
    /// Where the traits lead.
    public var links: LinkTable
    public var text: RulesText

    public init(id: String, name: String, category: String, text: RulesText) {
        self.id = id
        self.name = name
        self.category = category
        self.text = text
        cost = .none
        traits = []
        links = LinkTable()
    }
}
