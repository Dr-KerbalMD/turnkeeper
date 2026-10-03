import Foundation

/// The numeric effects of conditions on statistics, mirroring the FlatModifier rule elements of the
/// pf2e system's condition items.
public enum ConditionEffects {
    /// Conditions that bring others with them, such as prone making a creature off-guard.
    static let granted: [String: [AppliedCondition]] = [
        "prone": [AppliedCondition(slug: "off-guard")],
        "paralyzed": [AppliedCondition(slug: "off-guard")],
        "confused": [AppliedCondition(slug: "off-guard")],
        "grabbed": [AppliedCondition(slug: "off-guard"), AppliedCondition(slug: "immobilized")],
        "restrained": [AppliedCondition(slug: "off-guard"), AppliedCondition(slug: "immobilized")],
        "unconscious": [
            AppliedCondition(slug: "blinded"), AppliedCondition(slug: "off-guard"), AppliedCondition(slug: "prone")
        ],
        "dying": [AppliedCondition(slug: "unconscious")],
        "encumbered": [AppliedCondition(slug: "clumsy", value: 1)]
    ]

    /// Conditions that replace others while present.
    static let overrides: [String: String] = ["stunned": "slowed", "restrained": "grabbed"]

    /// The applied conditions plus the ones they grant, minus overridden ones, keeping the highest value
    /// of each condition.
    public static func effective(_ conditions: [AppliedCondition]) -> [AppliedCondition] {
        var all = conditions
        var index = 0
        while index < all.count {
            all += (granted[all[index].slug] ?? []).filter { grant in !all.contains { $0.slug == grant.slug } }
            index += 1
        }
        let overridden = Set(all.compactMap { overrides[$0.slug] })
        var result: [AppliedCondition] = []
        for condition in all where !overridden.contains(condition.slug) {
            guard !stacksSeparately(condition), let existing = result.firstIndex(where: { $0.slug == condition.slug })
            else {
                result.append(condition)
                continue
            }
            if (condition.value ?? 0) > (result[existing].value ?? 0) { result[existing] = condition }
        }
        return result
    }

    /// Persistent damage of different types, and GM reminders, are separate instances, not one condition.
    private static func stacksSeparately(_ condition: AppliedCondition) -> Bool {
        [ConditionSlug.persistentDamage, ConditionSlug.customReminder].contains(condition.slug)
    }

    /// The condition modifiers that apply to a statistic, after stacking.
    public static func modifiers(for statistic: Statistic, conditions: [AppliedCondition]) -> [Modifier] {
        let all = effective(conditions).flatMap { condition in
            effects(of: condition).filter { $0.applies(statistic) }.map { $0.modifier(for: condition) }
        }
        return Modifier.applying(all)
    }

    /// The change to maximum HP: drained costs its value times the level (at least 1) in HP.
    public static func hitPointChange(level: Int, conditions: [AppliedCondition]) -> Int {
        let drained = effective(conditions).first { $0.slug == ConditionSlug.drained }?.value ?? 0
        return -max(level, 1) * drained
    }

    private static func effects(of condition: AppliedCondition) -> [ConditionEffect] {
        table[condition.slug] ?? []
    }

    private static let table: [String: [ConditionEffect]] = [
        "frightened": [ConditionEffect(.status, .valued) { $0.isCheckOrDC }],
        "sickened": [ConditionEffect(.status, .valued) { $0.isCheckOrDC }],
        "clumsy": [ConditionEffect(.status, .valued) { $0.isCheckOrDC && $0.attribute == .dexterity }],
        "enfeebled": [ConditionEffect(.status, .valued) { $0.attribute == .strength && $0 != .speed }],
        "drained": [ConditionEffect(.status, .valued) { $0.attribute == .constitution }],
        "stupefied": [ConditionEffect(.status, .valued) { $0.isCheckOrDC && $0.isMentalBased }],
        "off-guard": [ConditionEffect(.circumstance, .fixed(2)) { $0 == .armorClass }],
        "prone": [ConditionEffect(.circumstance, .fixed(2)) { $0.isAttack }],
        "fatigued": [ConditionEffect(.status, .fixed(1)) { $0 == .armorClass || $0.isSave }],
        "blinded": [ConditionEffect(.status, .fixed(4)) { $0 == .perception }],
        "fascinated": [ConditionEffect(.status, .fixed(2)) { isPerceptionOrSkill($0) }],
        "unconscious": [ConditionEffect(.status, .fixed(4)) { [.armorClass, .perception, .reflex].contains($0) }],
        "suppressed": [
            ConditionEffect(.circumstance, .fixed(1)) { $0.isAttack },
            ConditionEffect(.status, .fixed(10)) { $0 == .speed }
        ],
        "encumbered": [ConditionEffect(.untyped, .fixed(10)) { $0 == .speed }]
    ]

    private static func isPerceptionOrSkill(_ statistic: Statistic) -> Bool {
        if case .skill = statistic { return true }
        return statistic == .perception
    }
}

/// One penalty a condition gives to the statistics it selects.
struct ConditionEffect: Sendable {
    enum Amount: Sendable {
        /// The condition's own value, such as 2 for frightened 2.
        case valued
        case fixed(Int)
    }

    var type: ModifierType
    var amount: Amount
    var applies: @Sendable (Statistic) -> Bool

    init(_ type: ModifierType, _ amount: Amount, applies: @escaping @Sendable (Statistic) -> Bool) {
        self.type = type
        self.amount = amount
        self.applies = applies
    }

    func modifier(for condition: AppliedCondition) -> Modifier {
        let size: Int
        switch amount {
        case .valued: size = condition.value ?? 1
        case let .fixed(value): size = value
        }
        let label = condition.value.map { "\(condition.slug) \($0)" } ?? condition.slug
        return Modifier(label: label, value: -size, type: type)
    }
}
