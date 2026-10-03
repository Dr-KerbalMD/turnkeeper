import Foundation

/// A creature's numbers with its template and conditions applied, each with the modifiers that changed it.
public struct StatBlockPresenter: Sendable {
    public let creature: Creature
    public let template: CreatureTemplate
    public let conditions: [AppliedCondition]

    public init(creature: Creature, template: CreatureTemplate = .normal, conditions: [AppliedCondition] = []) {
        self.creature = creature
        self.template = template
        self.conditions = conditions
    }

    public var level: Int { template.level(base: creature.level) }

    public var armorClass: AdjustedValue { value(creature.defenses.armorClass, .armorClass) }
    public var fortitude: AdjustedValue { value(creature.defenses.fortitude, .fortitude) }
    public var reflex: AdjustedValue { value(creature.defenses.reflex, .reflex) }
    public var will: AdjustedValue { value(creature.defenses.will, .will) }
    public var perception: AdjustedValue { value(creature.senses.perception, .perception) }

    public var initiative: AdjustedValue {
        let statistic: Statistic = creature.initiativeStatistic == "perception"
            ? .perception : .skill(Attribute.forSkill(creature.initiativeStatistic))
        return value(creature.initiativeModifier, statistic)
    }

    public func skill(_ skill: Skill) -> AdjustedValue {
        value(skill.modifier, .skill(Attribute.forSkill(skill.name.hasSuffix("Lore") ? "lore" : skill.name)))
    }

    public var maxHitPoints: AdjustedValue {
        var modifiers = [templateModifier(template.hitPointChange(baseLevel: creature.level))]
        let drained = ConditionEffects.hitPointChange(level: creature.level, conditions: conditions)
        if drained != 0 { modifiers.append(Modifier(label: "drained", value: drained, type: .untyped)) }
        let adjusted = AdjustedValue(base: creature.defenses.hitPoints, modifiers: modifiers)
        return adjusted.value >= 1 ? adjusted : AdjustedValue(base: creature.defenses.hitPoints, modifiers: [
            Modifier(label: "minimum 1", value: 1 - creature.defenses.hitPoints, type: .untyped)
        ])
    }

    public var speeds: [(speed: Speed, feet: AdjustedValue)] {
        creature.speeds.map { speed in
            let modifiers = ConditionEffects.modifiers(for: .speed, conditions: conditions)
            return (speed, AdjustedValue(base: speed.feet, modifiers: modifiers))
        }
    }

    // MARK: Strikes and spells

    /// The attribute a Strike uses: Dexterity for ranged and finesse Strikes when it's higher.
    public func attribute(of strike: Strike) -> Attribute {
        let attributes = creature.attributes
        let dexterityIsBetter = attributes.dexterity >= attributes.strength
        return strike.isRanged || (strike.traits.contains("finesse") && dexterityIsBetter) ? .dexterity : .strength
    }

    public func attack(_ strike: Strike) -> AdjustedValue {
        value(strike.attackBonus, .strikeAttack(attribute(of: strike)))
    }

    /// The Strike's damage: the template and Strength-based penalties change the first instance only.
    public func damage(_ strike: Strike) -> [AdjustedDamage] {
        let addsStrength = !strike.isRanged || strike.traits.contains { $0.hasPrefix("thrown") }
        let statistic: Statistic = .strikeDamage(addsStrength ? .strength : .dexterity)
        let conditionModifiers = ConditionEffects.modifiers(for: statistic, conditions: conditions)
        return adjusted(strike.damage, modifiers: [templateModifier(template.damageChange(isLimited: false))]
            + (addsStrength ? conditionModifiers : []))
    }

    public func spellDC(_ entry: Spellcasting) -> AdjustedValue { value(entry.difficultyClass, .spellDC) }
    public func spellAttack(_ entry: Spellcasting) -> AdjustedValue { value(entry.attack, .spellAttack) }

    // MARK: Ability text

    /// A DC in ability text is the creature's own, so the template and "all" penalties change it.
    /// Flat checks are never adjusted.
    public func check(_ check: CheckReference) -> AdjustedValue {
        guard check.statistic != "flat" else { return AdjustedValue(base: check.difficultyClass) }
        return value(check.difficultyClass, .abilityDC)
    }

    /// Damage in ability text changes by 2 with a template, or by 4 for limited-use abilities.
    public func damage(_ parts: [DamagePart], isLimited: Bool) -> [AdjustedDamage] {
        adjusted(parts, modifiers: [templateModifier(template.damageChange(isLimited: isLimited))])
    }

    // MARK: Helpers

    private func value(_ base: Int, _ statistic: Statistic) -> AdjustedValue {
        let modifiers = [templateModifier(template.statisticChange)]
            + ConditionEffects.modifiers(for: statistic, conditions: conditions)
        return AdjustedValue(base: base, modifiers: modifiers)
    }

    private func templateModifier(_ change: Int) -> Modifier {
        Modifier(label: template.rawValue, value: change, type: .untyped)
    }

    private func adjusted(_ parts: [DamagePart], modifiers: [Modifier]) -> [AdjustedDamage] {
        var applied = false
        return parts.map { part in
            let bonus = DamageFormula(part.formula)
            guard !applied, !part.isPersistent, bonus.isAdjustable else {
                return AdjustedDamage(part: part, dice: bonus.dice, bonus: AdjustedValue(base: bonus.constant))
            }
            applied = true
            let adjustedBonus = AdjustedValue(base: bonus.constant, modifiers: modifiers)
            return AdjustedDamage(part: part, dice: bonus.dice, bonus: adjustedBonus)
        }
    }
}

/// A damage instance with its constant adjusted, such as 2d8+11 becoming 2d8+13 for an elite creature.
public struct AdjustedDamage: Sendable, Hashable {
    public var part: DamagePart
    /// The dice, such as "2d8"; empty for flat damage.
    public var dice: String
    public var bonus: AdjustedValue

    /// The formula to show, such as "2d8+13" or "1d4-2".
    public var formula: String {
        let constant = bonus.value
        if dice.isEmpty { return String(max(constant, 0)) }
        return constant == 0 ? dice : "\(dice)\(constant > 0 ? "+" : "")\(constant)"
    }
}

/// Splits a formula like "2d8+11" into dice and a constant. Formulas with variables can't be adjusted.
struct DamageFormula {
    var dice: String
    var constant: Int
    var isAdjustable: Bool

    init(_ formula: String) {
        let pattern = /^(?<dice>\d*d\d+)?(?<constant>[+-]?\d+)?$/
        let match = formula.wholeMatch(of: pattern)
        guard let match, match.output.dice != nil || match.output.constant != nil else {
            dice = formula
            constant = 0
            isAdjustable = false
            return
        }
        dice = match.output.dice.map(String.init) ?? ""
        constant = match.output.constant.flatMap { Int($0) } ?? 0
        isAdjustable = true
    }
}
