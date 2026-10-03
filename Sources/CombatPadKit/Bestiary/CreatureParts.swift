import Foundation

/// AC, saves, HP and IWR.
public struct Defenses: Codable, Sendable, Hashable {
    public var armorClass: Int
    public var armorClassDetails: String
    public var fortitude: Int
    public var reflex: Int
    public var will: Int
    /// Notes such as "+1 status to all saves vs. magic".
    public var saveDetails: String
    public var hitPoints: Int
    public var hitPointDetails: String
    public var hardness: Int
    public var immunities: [String]
    public var resistances: [DamageAdjustment]
    public var weaknesses: [DamageAdjustment]

    public init(
        armorClass: Int, fortitude: Int, reflex: Int, will: Int, hitPoints: Int,
        details: DefenseDetails = DefenseDetails()
    ) {
        self.armorClass = armorClass
        self.fortitude = fortitude
        self.reflex = reflex
        self.will = will
        self.hitPoints = hitPoints
        armorClassDetails = details.armorClass
        saveDetails = details.saves
        hitPointDetails = details.hitPoints
        hardness = details.hardness
        immunities = details.immunities
        resistances = details.resistances
        weaknesses = details.weaknesses
    }
}

/// The less common parts of `Defenses`, grouped so the initializer stays short.
public struct DefenseDetails: Sendable {
    public var armorClass = ""
    public var saves = ""
    public var hitPoints = ""
    public var hardness = 0
    public var immunities: [String] = []
    public var resistances: [DamageAdjustment] = []
    public var weaknesses: [DamageAdjustment] = []

    public init() {}
}

/// A resistance or weakness, such as "physical 3 (except cold iron)".
public struct DamageAdjustment: Codable, Sendable, Hashable {
    public var type: String
    public var value: Int
    public var exceptions: [String]
    public var doubleVersus: [String]

    public init(type: String, value: Int, exceptions: [String] = [], doubleVersus: [String] = []) {
        self.type = type
        self.value = value
        self.exceptions = exceptions
        self.doubleVersus = doubleVersus
    }
}

/// The number of actions an ability or Strike takes.
public enum ActionCost: String, Codable, Sendable, Hashable {
    case none
    case one
    case two
    case three
    case free
    case reaction

    public init(actions: Int) {
        switch actions {
        case 1: self = .one
        case 2: self = .two
        case 3: self = .three
        default: self = .none
        }
    }
}

/// A stat-block Strike.
public struct Strike: Codable, Sendable, Hashable {
    public var name: String
    public var isRanged: Bool
    public var attackBonus: Int
    public var traits: [String]
    public var damage: [DamagePart]
    /// Extra effects on a hit, such as "Grab" or "Tangle Spores".
    public var effects: [String]
    /// The Starfinder area-fire or auto-fire action, when this is not a plain Strike.
    public var areaNote: String

    public init(name: String, isRanged: Bool, attackBonus: Int, traits: [String], damage: [DamagePart]) {
        self.name = name
        self.isRanged = isRanged
        self.attackBonus = attackBonus
        self.traits = traits
        self.damage = damage
        effects = []
        areaNote = ""
    }
}

/// One damage instance, such as "2d8+11 bludgeoning" or "1d6 persistent bleed".
public struct DamagePart: Codable, Sendable, Hashable {
    public var formula: String
    public var type: String
    public var isPersistent: Bool

    public init(formula: String, type: String, isPersistent: Bool = false) {
        self.formula = formula
        self.type = type
        self.isPersistent = isPersistent
    }
}

/// Where an ability sits in the stat block.
public enum AbilitySection: String, Codable, Sendable {
    /// After items: interaction abilities such as constant spells or auras.
    case interaction
    /// After HP: defensive abilities and reactions.
    case defensive
    /// After Strikes and spells: offensive actions.
    case offensive
}

public struct Ability: Codable, Sendable, Hashable {
    public var name: String
    public var cost: ActionCost
    public var traits: [String]
    public var section: AbilitySection
    /// "1/day" or "1/round" when the ability is limited, which doubles template damage changes.
    public var frequency: String
    public var text: RulesText

    public var isLimited: Bool { !frequency.isEmpty }

    public init(name: String, cost: ActionCost, section: AbilitySection, text: RulesText) {
        self.name = name
        self.cost = cost
        self.section = section
        self.text = text
        traits = []
        frequency = ""
    }
}

/// Hazard-only text and Stealth.
public struct HazardDetails: Codable, Sendable, Hashable {
    public var stealth: Int
    public var stealthDetails: RulesText
    public var description: RulesText
    public var disable: RulesText
    public var routine: RulesText
    public var reset: RulesText

    public init(stealth: Int, description: RulesText) {
        self.stealth = stealth
        self.description = description
        stealthDetails = RulesText()
        disable = RulesText()
        routine = RulesText()
        reset = RulesText()
    }
}
