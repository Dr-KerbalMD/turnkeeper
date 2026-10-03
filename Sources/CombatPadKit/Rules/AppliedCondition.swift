import Foundation

/// When during a turn something should be brought to the GM's attention.
public enum TurnMoment: String, Codable, Sendable {
    case startOfTurn
    case endOfTurn
}

/// A condition on a combatant, with its value and any extra data the condition needs.
public struct AppliedCondition: Codable, Sendable, Hashable, Identifiable {
    public var id: UUID
    public var slug: String
    /// The condition's number, such as 2 for frightened 2. Nil for conditions without one.
    public var value: Int?
    /// For persistent damage: the formula and type, such as 1d6 bleed.
    public var persistentDamage: DamagePart?
    /// For custom reminders: the text and when it shows.
    public var note: String
    public var noteMoment: TurnMoment?

    public init(slug: String, value: Int? = nil) {
        id = UUID()
        self.slug = slug
        self.value = value
        persistentDamage = nil
        note = ""
        noteMoment = nil
    }

    public static func persistent(_ damage: DamagePart) -> AppliedCondition {
        var condition = AppliedCondition(slug: ConditionSlug.persistentDamage)
        condition.persistentDamage = damage
        return condition
    }

    public static func reminder(_ note: String, at moment: TurnMoment) -> AppliedCondition {
        var condition = AppliedCondition(slug: ConditionSlug.customReminder)
        condition.note = note
        condition.noteMoment = moment
        return condition
    }
}

/// Condition slugs the rules refer to by name.
public enum ConditionSlug {
    public static let persistentDamage = "persistent-damage"
    /// Not a rules condition: a GM note that shows at the start or end of a turn.
    public static let customReminder = "custom-reminder"
    public static let frightened = "frightened"
    public static let slowed = "slowed"
    public static let stunned = "stunned"
    public static let quickened = "quickened"
    public static let dying = "dying"
    public static let wounded = "wounded"
    public static let drained = "drained"
}
