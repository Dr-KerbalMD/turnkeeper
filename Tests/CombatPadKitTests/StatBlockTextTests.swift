import Foundation
import Testing
@testable import CombatPadKit

@Suite("Stat block text")
struct StatBlockTextTests {
    @Test("Signed numbers read Paizo's minus signs")
    func integers() {
        #expect(StatBlockText.integer("+7") == 7)
        #expect(StatBlockText.integer("−2") == -2)
        #expect(StatBlockText.integer("–1") == -1)
        #expect(StatBlockText.integer("x") == nil)
    }

    @Test("Skills, speeds and resistances round-trip")
    func lists() {
        let skills = StatBlockText.skills("Acrobatics +5, Warfare Lore +7 (+9 to recall), Stealth −1")
        #expect(skills == [Skill(name: "Acrobatics", modifier: 5),
                           Skill(name: "Warfare Lore", modifier: 7, details: "+9 to recall"),
                           Skill(name: "Stealth", modifier: -1)])
        #expect(StatBlockText.skills(StatBlockText.format(skills)) == skills)
        #expect(StatBlockText.speeds("25 feet, fly 40 feet")
                == [Speed(type: "land", feet: 25), Speed(type: "fly", feet: 40)])
        let resistances = StatBlockText.adjustments("fire 5, physical 5 (except silver, cold iron)")
        #expect(resistances[1] == DamageAdjustment(type: "physical", value: 5, exceptions: ["silver", "cold iron"]))
    }

    @Test("Damage lines split into parts, with persistent damage marked")
    func damage() {
        #expect(StatBlockText.damage("2d8+11 bludgeoning plus 1d6 fire") == [
            DamagePart(formula: "2d8+11", type: "bludgeoning"), DamagePart(formula: "1d6", type: "fire")
        ])
        #expect(StatBlockText.damage("1d6 persistent fire damage") == [
            DamagePart(formula: "1d6", type: "fire", isPersistent: true)
        ])
        #expect(StatBlockText.format(StatBlockText.damage("2d6 − 1 bleed")) == "2d6-1 bleed")
    }

    @Test("Spell ranks read the printed line")
    func spells() {
        let ranks = StatBlockText.spellRanks("4th dispel magic, wall of fire (×2); Cantrips (2nd) light, shield; "
                                             + "Constant (5th) see invisibility")
        #expect(ranks.map(\.kind) == [.ranked, .cantrips, .constant])
        #expect(ranks[0].rank == 4 && ranks[0].spells[1] == SpellEntry(name: "wall of fire", note: "×2"))
        #expect(ranks[1].rank == 2 && ranks[1].spells.map(\.name) == ["light", "shield"])
        #expect(StatBlockText.spellRanks(StatBlockText.format(ranks)) == ranks)
    }

    @Test("Rules text finds checks, damage and action symbols")
    func rules() {
        let text = StatBlockText.rulesText(
            "◆◆ Each creature in a 30-foot cone takes 6d6 fire damage (DC 25 basic Reflex save).")
        #expect(text.markup == "{{actions:2}} Each creature in a 30-foot cone takes {{damage:6d6|fire}} damage "
                + "({{check:reflex:25:basic}} save).")
        #expect(StatBlockText.plainText(text) == "◆◆ Each creature in a 30-foot cone takes 6d6 fire damage "
                + "(DC 25 basic Reflex save).")
        #expect(StatBlockText.rulesText("**Trigger** A foe moves.\nDC 5 flat check").markup
                == "**Trigger** A foe moves.\n{{check:flat:5}}")
    }

    @Test("A draft round-trips a creature")
    func draft() {
        var creature = Creature(key: "custom.x", name: "Gwibble", game: .pathfinder)
        creature.level = 3
        creature.skills = [Skill(name: "Stealth", modifier: 9)]
        creature.strikes = [Strike(name: "jaws", isRanged: false, attackBonus: 12, traits: ["agile"],
                                   damage: [DamagePart(formula: "2d6+4", type: "piercing")])]
        creature.abilities = [Ability(name: "Spit", cost: .two, section: .offensive,
                                      text: RulesText("{{damage:3d6|acid}} ({{check:reflex:20:basic}})"))]
        let rebuilt = CreatureDraft(creature).creature(from: creature)
        #expect(rebuilt.skills == creature.skills)
        #expect(rebuilt.strikes == creature.strikes)
        #expect(rebuilt.abilities.first?.text == creature.abilities.first?.text)
        #expect(rebuilt.level == 3)
    }
}
