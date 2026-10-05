import Foundation

/// The game a creature or campaign belongs to.
public enum Game: String, Codable, Sendable, CaseIterable {
    case pathfinder = "pf2e"
    case starfinder = "sf2e"
}

/// What sort of bestiary entry this is. Only complex hazards are imported, since simple ones never
/// take a turn.
public enum CreatureKind: String, Codable, Sendable {
    case creature
    case hazard
}

/// A creature or complex hazard as its stat block shows it, before templates or conditions.
public struct Creature: Codable, Sendable, Identifiable, Hashable {
    /// Stable key, `<game>.<pack>.<foundry _id>`.
    public var key: String
    public var name: String
    public var game: Game
    public var kind: CreatureKind
    public var level: Int
    public var traits: TraitLine
    public var source: Source
    public var senses: Senses
    public var languages: [String]
    public var skills: [Skill]
    public var attributes: AttributeModifiers
    public var items: [String]
    public var defenses: Defenses
    public var speeds: [Speed]
    public var strikes: [Strike]
    public var spellcasting: [Spellcasting]
    public var abilities: [Ability]
    /// The statistic rolled for initiative: "perception", "stealth" or a skill slug.
    public var initiativeStatistic: String
    /// Present only for hazards.
    public var hazard: HazardDetails?
    public var art: ArtReference
    /// Glossary links for spells, items, Strike effects and traits. Nil for creatures saved before links
    /// existed, and for custom creatures.
    public var links: LinkTable?

    public var id: String { key }

    /// The modifier rolled for initiative, from the statistic the creature uses.
    public var initiativeModifier: Int {
        switch initiativeStatistic {
        case "perception": return senses.perception
        case "stealth": return hazard?.stealth ?? skills.first { $0.name == "Stealth" }?.modifier ?? senses.perception
        default:
            return skills.first { $0.name.lowercased() == initiativeStatistic }?.modifier ?? senses.perception
        }
    }

    /// An empty creature to fill in; every statistic starts at zero or empty.
    public init(key: String, name: String, game: Game) {
        self.key = key
        self.name = name
        self.game = game
        kind = .creature
        level = 0
        traits = TraitLine(rarity: "common", size: "Medium", traits: [])
        source = Source(pack: "", title: "", isRemastered: true)
        senses = Senses(perception: 0, details: "", senses: [])
        languages = []
        skills = []
        attributes = .zero
        items = []
        defenses = Defenses(armorClass: 10, fortitude: 0, reflex: 0, will: 0, hitPoints: 1)
        speeds = []
        strikes = []
        spellcasting = []
        abilities = []
        initiativeStatistic = "perception"
        hazard = nil
        art = .none
    }
}

/// Rarity, size and the other traits, in stat-block order.
public struct TraitLine: Codable, Sendable, Hashable {
    public var rarity: String
    public var size: String
    public var traits: [String]

    public init(rarity: String, size: String, traits: [String]) {
        self.rarity = rarity
        self.size = size
        self.traits = traits
    }
}

/// The book a creature comes from.
public struct Source: Codable, Sendable, Hashable {
    public var pack: String
    public var title: String
    public var isRemastered: Bool

    public init(pack: String, title: String, isRemastered: Bool) {
        self.pack = pack
        self.title = title
        self.isRemastered = isRemastered
    }
}

public struct Senses: Codable, Sendable, Hashable {
    public var perception: Int
    public var details: String
    public var senses: [String]

    public init(perception: Int, details: String, senses: [String]) {
        self.perception = perception
        self.details = details
        self.senses = senses
    }
}

/// A skill or lore entry. Lore skills keep their full name, such as "Legal Lore".
public struct Skill: Codable, Sendable, Hashable {
    public var name: String
    public var modifier: Int
    public var details: String

    public init(name: String, modifier: Int, details: String = "") {
        self.name = name
        self.modifier = modifier
        self.details = details
    }
}

public struct AttributeModifiers: Codable, Sendable, Hashable {
    public var strength: Int
    public var dexterity: Int
    public var constitution: Int
    public var intelligence: Int
    public var wisdom: Int
    public var charisma: Int

    public static let zero = AttributeModifiers(
        strength: 0, dexterity: 0, constitution: 0, intelligence: 0, wisdom: 0, charisma: 0
    )

    public init(strength: Int, dexterity: Int, constitution: Int, intelligence: Int, wisdom: Int, charisma: Int) {
        self.strength = strength
        self.dexterity = dexterity
        self.constitution = constitution
        self.intelligence = intelligence
        self.wisdom = wisdom
        self.charisma = charisma
    }
}

public struct Speed: Codable, Sendable, Hashable {
    /// "land", "fly", "swim", "climb" or "burrow".
    public var type: String
    public var feet: Int

    public init(type: String, feet: Int) {
        self.type = type
        self.feet = feet
    }
}

/// Where a creature's art lives inside the bundled `Generated` folder. Empty paths mean no art.
public struct ArtReference: Codable, Sendable, Hashable {
    /// Full-figure art for the battle card and the player view.
    public var portrait: String
    /// Round token art for tiles.
    public var token: String
    /// A whole Battle Card back, frame included, for the player view.
    public var cardBack: String

    public static let none = ArtReference(portrait: "", token: "", cardBack: "")

    public var hasArt: Bool { !portrait.isEmpty || !token.isEmpty || !cardBack.isEmpty }

    public init(portrait: String, token: String, cardBack: String = "") {
        self.portrait = portrait
        self.token = token
        self.cardBack = cardBack
    }
}
