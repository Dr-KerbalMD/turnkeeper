import Foundation
import Testing
@testable import CombatPadKit

@Suite("Starting a fight")
struct CombatSetupTests {
    private func entry(
        _ key: String, _ name: String, level: Int, kind: CreatureKind = .creature
    ) -> BestiaryIndexEntry {
        var creature = Creature(key: key, name: name, game: .pathfinder)
        creature.level = level
        creature.kind = kind
        return BestiaryIndexEntry(creature: creature)
    }

    private var bestiary: [String: BestiaryIndexEntry] {
        ["goblin": entry("goblin", "Goblin Warrior", level: -1), "boss": entry("boss", "Goblin War Chanter", level: 1),
         "pit": entry("pit", "Drowning Pit", level: 3, kind: .hazard)]
    }

    @Test("Creatures are numbered across slots, benched ones wait, and PCs join")
    func combatants() {
        var variant = EncounterVariant(label: "Base")
        var goblins = EncounterSlot(creatureKey: "goblin")
        goblins.count = 2
        var reserve = EncounterSlot(creatureKey: "goblin")
        reserve.startsOnBench = true
        variant.slots = [goblins, reserve, EncounterSlot(creatureKey: "pit")]
        let party = Party(campaignID: UUID(), name: "Table 1", level: 1, members: [PartyMember(name: "Kyra")])
        let state = CombatSetup.state(for: variant, party: party) { bestiary[$0] }
        #expect(state.combatants.map(\.name) == ["Kyra", "Goblin Warrior 1", "Goblin Warrior 2", "Goblin Warrior 3",
                                                 "Drowning Pit"])
        #expect(state.bench.map(\.name) == ["Goblin Warrior 3"])
        #expect(state.combatants.last?.kind == .hazard)
        #expect(state.combatants.last?.magnet == .gray)
        #expect(state.phase == .setup)
    }

    @Test("A variant's XP uses template-adjusted levels and leaves out allies")
    func experience() {
        var variant = EncounterVariant(label: "Base")
        var elite = EncounterSlot(creatureKey: "boss")
        elite.template = .elite
        var goblins = EncounterSlot(creatureKey: "goblin")
        goblins.count = 2
        variant.slots = [elite, goblins, .customNPC(name: "Guide", level: 3, hitPoints: 30)]
        let budget = EncounterBudget(partyLevel: 1, partySize: 4)
        // Elite level-1 boss is level 2 (+1: 60 XP); goblins at -1 are party level -2 (20 XP each).
        #expect(budget.experience(of: variant) { bestiary[$0] } == 100)
    }

    @Test("Initiative is a d20 roll plus the modifier")
    func rolls() {
        var generator = SystemRandomNumberGenerator()
        let rolls = (0..<200).map { _ in CombatSetup.rollInitiative(modifier: 5, using: &generator) }
        #expect(rolls.allSatisfy { (6...25).contains($0) })
    }
}

@Suite("Stat block presentation")
struct StatBlockPresenterTests {
    private var warrior: Creature {
        var creature = Creature(key: "k", name: "Warrior", game: .pathfinder)
        creature.level = 5
        creature.defenses = Defenses(armorClass: 22, fortitude: 12, reflex: 10, will: 8, hitPoints: 75)
        creature.attributes = AttributeModifiers(
            strength: 4, dexterity: 2, constitution: 3, intelligence: 0, wisdom: 1, charisma: 0
        )
        creature.strikes = [
            Strike(name: "maul", isRanged: false, attackBonus: 15,
                   traits: [], damage: [DamagePart(formula: "2d12+7", type: "bludgeoning")]),
            Strike(name: "dagger", isRanged: false, attackBonus: 14,
                   traits: ["finesse"], damage: [DamagePart(formula: "1d4", type: "piercing")])
        ]
        return creature
    }

    @Test("Elite raises statistics, HP and the first damage instance")
    func elite() {
        let elite = StatBlockPresenter(creature: warrior, template: .elite)
        #expect(elite.level == 6)
        #expect(elite.armorClass.value == 24)
        #expect(elite.maxHitPoints.value == 95)
        #expect(elite.damage(warrior.strikes[0]).map(\.formula) == ["2d12+9"])
    }

    @Test("Conditions show in the numbers with their sources")
    func conditions() {
        let conditions = [AppliedCondition(slug: "enfeebled", value: 2), AppliedCondition(slug: "off-guard")]
        let presenter = StatBlockPresenter(creature: warrior, template: .weak, conditions: conditions)
        #expect(presenter.armorClass.value == 18)
        #expect(presenter.armorClass.modifiers.map(\.label) == ["weak", "off-guard"])
        #expect(presenter.attack(warrior.strikes[0]).value == 11)
        #expect(presenter.damage(warrior.strikes[0]).map(\.formula) == ["2d12+3"])
        #expect(presenter.attribute(of: warrior.strikes[1]) == .strength)
    }

    @Test("Ability damage changes by 4 when limited; flat checks never change")
    func abilityText() {
        let elite = StatBlockPresenter(creature: warrior, template: .elite)
        let breath = [DamagePart(formula: "6d6", type: "fire")]
        #expect(elite.damage(breath, isLimited: true).map(\.formula) == ["6d6+4"])
        #expect(elite.check(CheckReference(statistic: "reflex", difficultyClass: 22)).value == 24)
        #expect(elite.check(CheckReference(statistic: "flat", difficultyClass: 5)).value == 5)
    }

    @Test("Weak damage can go negative on the constant; unparseable formulas are left alone")
    func formulas() {
        let weak = StatBlockPresenter(creature: warrior, template: .weak)
        #expect(weak.damage([DamagePart(formula: "1d4", type: "")], isLimited: false).map(\.formula) == ["1d4-2"])
        #expect(weak.damage([DamagePart(formula: "(@item.level)d6", type: "")], isLimited: false)
            .map(\.formula) == ["(@item.level)d6"])
    }
}
