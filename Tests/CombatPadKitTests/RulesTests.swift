import Testing
@testable import CombatPadKit

@Suite("Elite and weak templates")
struct CreatureTemplateTests {
    @Test("Level changes, with the special cases at -1, 0 and 1", arguments: [
        (-1, 1, -2), (0, 2, -1), (1, 2, -1), (2, 3, 1), (5, 6, 4), (20, 21, 19), (21, 22, 20)
    ])
    func levels(base: Int, elite: Int, weak: Int) {
        #expect(CreatureTemplate.elite.level(base: base) == elite)
        #expect(CreatureTemplate.weak.level(base: base) == weak)
        #expect(CreatureTemplate.normal.level(base: base) == base)
    }

    @Test("HP changes by the base level's bracket", arguments: [
        (-1, 10, 0), (0, 10, 0), (1, 10, -10), (2, 15, -10), (3, 15, -15), (5, 20, -15),
        (6, 20, -20), (19, 20, -20), (20, 30, -20), (21, 30, -30)
    ])
    func hitPoints(level: Int, elite: Int, weak: Int) {
        #expect(CreatureTemplate.elite.hitPointChange(baseLevel: level) == elite)
        #expect(CreatureTemplate.weak.hitPointChange(baseLevel: level) == weak)
    }

    @Test("Statistics change by 2, and limited abilities' damage by 4")
    func statisticsAndDamage() {
        #expect(CreatureTemplate.elite.statisticChange == 2)
        #expect(CreatureTemplate.weak.statisticChange == -2)
        #expect(CreatureTemplate.elite.damageChange(isLimited: true) == 4)
        #expect(CreatureTemplate.weak.damageChange(isLimited: false) == -2)
    }
}

@Suite("Encounter budget")
struct EncounterBudgetTests {
    @Test("XP by level difference, clamped to the table's ends", arguments: [
        (-6, 10), (-4, 10), (-3, 15), (-2, 20), (-1, 30), (0, 40), (1, 60), (2, 80), (3, 120), (4, 160), (6, 160)
    ])
    func experience(difference: Int, experience: Int) {
        let budget = EncounterBudget(partyLevel: 5, partySize: 4)
        #expect(budget.experience(forLevel: 5 + difference) == experience)
        #expect(budget.isOutsideTable(level: 5 + difference) == (abs(difference) > 4))
    }

    @Test("Budgets for parties of 3, 4 and 5", arguments: [
        (3, [30, 45, 60, 90, 120]), (4, [40, 60, 80, 120, 160]), (5, [50, 75, 100, 150, 200])
    ])
    func budgets(size: Int, expected: [Int]) {
        let budget = EncounterBudget(partyLevel: 3, partySize: size)
        #expect(ThreatLevel.allCases.map(budget.budget(for:)) == expected)
    }

    @Test("The table's levels are party level ±4, kept within −1…25", arguments: [
        (3, -1...7), (10, 6...14), (0, -1...4), (24, 20...25), (-1, -1...3), (40, 25...25)
    ])
    func tableLevels(partyLevel: Int, expected: ClosedRange<Int>) {
        #expect(EncounterBudget(partyLevel: partyLevel, partySize: 4).tableLevels == expected)
    }

    @Test("Threat is the lowest tier that covers the XP; above severe is extreme")
    func threat() {
        let budget = EncounterBudget(partyLevel: 3, partySize: 4)
        #expect(budget.threat(forExperience: 40) == .trivial)
        #expect(budget.threat(forExperience: 41) == .low)
        #expect(budget.threat(forExperience: 80) == .moderate)
        #expect(budget.threat(forExperience: 121) == .extreme)
        #expect(!budget.isBeyondExtreme(experience: 160))
        #expect(budget.isBeyondExtreme(experience: 161))
    }
}

@Suite("Condition effects")
struct ConditionEffectsTests {
    private func total(_ statistic: Statistic, _ conditions: [AppliedCondition]) -> Int {
        ConditionEffects.modifiers(for: statistic, conditions: conditions).reduce(0) { $0 + $1.value }
    }

    @Test("Status penalties don't stack: frightened 2 and sickened 1 give -2")
    func statusStacking() {
        let conditions = [AppliedCondition(slug: "frightened", value: 2), AppliedCondition(slug: "sickened", value: 1)]
        #expect(total(.will, conditions) == -2)
        #expect(total(.strikeDamage(.strength), conditions) == 0)
    }

    @Test("Status and circumstance penalties add: frightened 1 and off-guard give AC -3")
    func differentTypes() {
        let conditions = [AppliedCondition(slug: "frightened", value: 1), AppliedCondition(slug: "off-guard")]
        #expect(total(.armorClass, conditions) == -3)
    }

    @Test("Clumsy affects AC, Reflex and Dex attacks but not Will")
    func clumsy() {
        let clumsy = [AppliedCondition(slug: "clumsy", value: 2)]
        #expect(total(.armorClass, clumsy) == -2)
        #expect(total(.reflex, clumsy) == -2)
        #expect(total(.strikeAttack(.dexterity), clumsy) == -2)
        #expect(total(.will, clumsy) == 0)
        #expect(total(.strikeAttack(.strength), clumsy) == 0)
    }

    @Test("Enfeebled affects Strength attacks and damage; stupefied affects spells and Will")
    func enfeebledAndStupefied() {
        let enfeebled = [AppliedCondition(slug: "enfeebled", value: 1)]
        #expect(total(.strikeAttack(.strength), enfeebled) == -1)
        #expect(total(.strikeDamage(.strength), enfeebled) == -1)
        #expect(total(.armorClass, enfeebled) == 0)
        let stupefied = [AppliedCondition(slug: "stupefied", value: 3)]
        #expect(total(.spellDC, stupefied) == -3)
        #expect(total(.will, stupefied) == -3)
        #expect(total(.fortitude, stupefied) == 0)
    }

    @Test("Granted conditions: unconscious brings blinded, off-guard and prone")
    func granted() {
        let unconscious = [AppliedCondition(slug: "unconscious")]
        let slugs = ConditionEffects.effective(unconscious).map(\.slug)
        #expect(Set(slugs) == ["unconscious", "blinded", "off-guard", "prone"])
        #expect(total(.armorClass, unconscious) == -6)
        #expect(total(.perception, unconscious) == -4)
    }

    @Test("Stunned overrides slowed; the highest value of a condition counts")
    func overridesAndValues() {
        let conditions = [
            AppliedCondition(slug: "stunned", value: 1), AppliedCondition(slug: "slowed", value: 1),
            AppliedCondition(slug: "frightened", value: 1), AppliedCondition(slug: "frightened", value: 3)
        ]
        let effective = ConditionEffects.effective(conditions)
        #expect(!effective.contains { $0.slug == "slowed" })
        #expect(effective.filter { $0.slug == "frightened" }.map(\.value) == [3])
    }

    @Test("Drained lowers max HP by its value times the level")
    func drained() {
        let drained = [AppliedCondition(slug: "drained", value: 2)]
        #expect(ConditionEffects.hitPointChange(level: 5, conditions: drained) == -10)
        #expect(ConditionEffects.hitPointChange(level: -1, conditions: drained) == -2)
        #expect(total(.fortitude, drained) == -2)
    }

    @Test("Persistent damage of different types stays separate")
    func persistentInstances() {
        let conditions = [
            AppliedCondition.persistent(DamagePart(formula: "1d6", type: "bleed", isPersistent: true)),
            AppliedCondition.persistent(DamagePart(formula: "2d4", type: "fire", isPersistent: true))
        ]
        #expect(ConditionEffects.effective(conditions).count == 2)
    }
}
