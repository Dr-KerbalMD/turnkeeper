import Foundation
import Testing
@testable import CombatPadKit

/// Stat blocks as Pluck copies them: JSON with bold labels kept inline as bold runs.
private enum Fixtures {
    static let creatures = #"""
    {"format": 1, "blocks": [
      {"name": "GWIBBLE", "level": "Creature 3", "traits": ["UNIQUE", "CE", "SMALL", "FEY"], "variant": "1-2",
       "source": "Pathfinder Society Scenario #7-99", "entries": [
        {"name": "Perception", "runs": [{"text": " +9; darkvision, scent (imprecise) 30 feet",
                                         "isBold": false, "isItalic": false}]},
        {"name": "Languages", "runs": [{"text": " Common, Sylvan; telepathy 30 feet", "isBold": false,
                                        "isItalic": false}]},
        {"name": "Skills", "runs": [{"text": " Acrobatics +10, Stealth +12", "isBold": false, "isItalic": false}]},
        {"name": "Str", "runs": [{"text": " −1, ", "isBold": false, "isItalic": false},
                                 {"text": "Dex", "isBold": true, "isItalic": false},
                                 {"text": " +4, ", "isBold": false, "isItalic": false},
                                 {"text": "Con", "isBold": true, "isItalic": false},
                                 {"text": " +1, Int +0, Wis +2, Cha +3", "isBold": false, "isItalic": false}]},
        {"name": "AC", "runs": [{"text": " 19 (21 with shield raised); ", "isBold": false, "isItalic": false},
                                {"text": "Fort", "isBold": true, "isItalic": false},
                                {"text": " +7, Ref +11, Will +9; +1 status to all saves vs. magic",
                                 "isBold": false, "isItalic": false}]},
        {"name": "HP", "runs": [{"text": " 45, regeneration 5 (deactivated by fire); ", "isBold": false,
                                 "isItalic": false},
                                {"text": "Weaknesses", "isBold": true, "isItalic": false},
                                {"text": " cold iron 5; Resistances physical 3 (except silver)",
                                 "isBold": false, "isItalic": false}]},
        {"name": "Spiteful Retort", "runs": [{"text": " [reaction] (emotion, mental) ", "isBold": false,
                                              "isItalic": false},
                                             {"text": "Trigger", "isBold": true, "isItalic": false},
                                             {"text": " A creature mocks the gwibble. ", "isBold": false,
                                              "isItalic": false},
                                             {"text": "Effect", "isBold": true, "isItalic": false},
                                             {"text": " The creature takes 2d6 mental damage (DC 20 basic Will save).",
                                              "isBold": false, "isItalic": false}]},
        {"name": "Speed", "runs": [{"text": " 25 feet, fly 30 feet", "isBold": false, "isItalic": false}]},
        {"name": "Melee", "runs": [{"text": " [one-action] jaws +12 [+8/+4] (agile, finesse), ", "isBold": false,
                                    "isItalic": false},
                                   {"text": "Damage", "isBold": true, "isItalic": false},
                                   {"text": " 2d6+4 piercing plus 1d4 persistent bleed and Grab", "isBold": false,
                                    "isItalic": false}]},
        {"name": "Ranged", "runs": [{"text": " [one-action] spit +11 (range increment 20 feet), Damage 1d8 acid",
                                     "isBold": false, "isItalic": false}]},
        {"name": "Primal Innate Spells", "runs": [{"text": " DC 20, attack +12; 2nd ", "isBold": false,
                                                   "isItalic": false},
                                                  {"text": "faerie fire", "isBold": false, "isItalic": true},
                                                  {"text": "; Cantrips (2nd) light, prestidigitation",
                                                   "isBold": false, "isItalic": false}]},
        {"name": "Melee", "runs": [{"text": " [one-action] it bites", "isBold": false, "isItalic": false}]},
        {"name": "", "runs": [{"text": "The gwibble cackles.", "isBold": false, "isItalic": false}]}
      ]},
      {"name": "RUSTY SPEAR TRAP", "level": "Hazard 2", "traits": ["MECHANICAL", "TRAP"], "variant": "3-4",
       "entries": [
        {"name": "Stealth", "runs": [{"text": " +10 (trained)", "isBold": false, "isItalic": false}]},
        {"name": "Description", "runs": [{"text": " Spears jab from the walls.", "isBold": false, "isItalic": false}]},
        {"name": "Disable", "runs": [{"text": " DC 18 Thievery (trained) to jam the spears", "isBold": false,
                                      "isItalic": false}]},
        {"name": "AC", "runs": [{"text": " 18; Fort +11, Ref +5", "isBold": false, "isItalic": false}]},
        {"name": "Hardness", "runs": [{"text": " 6, HP 24 (BT 12); Immunities critical hits, object immunities",
                                       "isBold": false, "isItalic": false}]},
        {"name": "Routine", "runs": [{"text": " (1 action) The trap makes a Strike.", "isBold": false,
                                      "isItalic": false}]},
        {"name": "Reset", "runs": [{"text": " The trap resets after 1 minute.", "isBold": false, "isItalic": false}]}
      ]}
    ]}
    """#

    static func blocks() throws -> [PluckStatBlock] {
        try PluckStatBlock.blocks(from: Data(creatures.utf8))
    }

    static func convert(_ block: PluckStatBlock) -> StatBlockConverter.Conversion {
        StatBlockConverter.convert(block, key: "custom.test", game: .pathfinder)
    }
}

@Suite("Converting stat blocks from Pluck")
struct StatBlockConverterTests {
    @Test("Name, level, traits and statistics")
    func statistics() throws {
        let creature = Fixtures.convert(try Fixtures.blocks()[0]).creature
        #expect(creature.name == "Gwibble" && creature.kind == .creature && creature.level == 3)
        #expect(creature.traits == TraitLine(rarity: "unique", size: "Small", traits: ["fey"]))
        #expect(creature.source.title == "Pathfinder Society Scenario #7-99")
        #expect(creature.senses.perception == 9)
        #expect(creature.senses.senses == ["darkvision", "scent (imprecise) 30 feet"])
        #expect(creature.languages == ["Common", "Sylvan", "telepathy 30 feet"])
        #expect(creature.skills.map(\.modifier) == [10, 12])
        #expect(creature.attributes.strength == -1 && creature.attributes.dexterity == 4)
        #expect(creature.attributes.charisma == 3)
    }

    @Test("Defenses, with their notes, weaknesses and resistances")
    func defenses() throws {
        let defenses = Fixtures.convert(try Fixtures.blocks()[0]).creature.defenses
        #expect(defenses.armorClass == 19 && defenses.armorClassDetails == "21 with shield raised")
        #expect(defenses.fortitude == 7 && defenses.reflex == 11 && defenses.will == 9)
        #expect(defenses.saveDetails == "+1 status to all saves vs. magic")
        #expect(defenses.hitPoints == 45 && defenses.hitPointDetails == "regeneration 5 (deactivated by fire)")
        #expect(defenses.weaknesses == [DamageAdjustment(type: "cold iron", value: 5)])
        #expect(defenses.resistances == [DamageAdjustment(type: "physical", value: 3, exceptions: ["silver"])])
    }

    @Test("Strikes, spells and abilities, with unreadable lines kept as text")
    func offense() throws {
        let conversion = Fixtures.convert(try Fixtures.blocks()[0])
        let creature = conversion.creature
        #expect(creature.speeds == [Speed(type: "land", feet: 25), Speed(type: "fly", feet: 30)])
        let jaws = try #require(creature.strikes.first)
        #expect(jaws.name == "jaws" && jaws.attackBonus == 12 && jaws.traits == ["agile", "finesse"])
        #expect(jaws.damage == [DamagePart(formula: "2d6+4", type: "piercing"),
                                DamagePart(formula: "1d4", type: "bleed", isPersistent: true)])
        #expect(creature.strikes[1].isRanged)
        #expect(creature.strikes[1].damage == [DamagePart(formula: "1d8", type: "acid")])
        let spells = try #require(creature.spellcasting.first)
        #expect(spells.difficultyClass == 20 && spells.attack == 12 && spells.ranks.count == 2)
        let retort = try #require(creature.abilities.first)
        #expect(retort.cost == .reaction && retort.section == .defensive && retort.traits == ["emotion", "mental"])
        #expect(retort.text.markup.contains("{{check:will:20:basic}}"))
        #expect(retort.text.markup.contains("**Trigger**"))
        #expect(creature.abilities.last?.name == "Melee")
        #expect(StatBlockText.plainText(creature.abilities.last!.text).hasSuffix("The gwibble cackles."))
        #expect(conversion.warnings == ["Melee: couldn't read the attack"])
    }

    @Test("A complex hazard's Stealth, defenses and text")
    func hazard() throws {
        let conversion = Fixtures.convert(try Fixtures.blocks()[1])
        let hazard = conversion.creature
        #expect(hazard.kind == .hazard && hazard.level == 2 && hazard.initiativeStatistic == "stealth")
        #expect(hazard.hazard?.stealth == 10)
        #expect(hazard.hazard?.disable.markup.contains("{{check:thievery:18}}") == true)
        #expect(hazard.defenses.hardness == 6 && hazard.defenses.hitPoints == 24)
        #expect(hazard.defenses.hitPointDetails == "(BT 12)")
        #expect(hazard.defenses.immunities == ["critical hits", "object immunities"])
        #expect(hazard.hazard?.routine.markup.isEmpty == false && conversion.warnings.isEmpty)
    }

    @Test("Plain text is read into the same blocks")
    func plainText() {
        let text = """
        Gwibble (1-2) — Creature 3
        Unique, Small, Fey
        Perception +9; darkvision
        AC 19; Fort +7, Ref +11, Will +9
        HP 45
        Spiteful Retort ⤾ Trigger A creature mocks the gwibble.
        Effect The creature takes 2d6 mental damage.
        Speed 25 feet
        Melee ◆ jaws +12 (agile), Damage 2d6+4 piercing
        Primal Innate Spells DC 20, attack +12; 2nd faerie fire
        """
        let blocks = PluckStatBlock.blocks(fromPlainText: text)
        #expect(blocks.count == 1 && blocks[0].variant == "1-2" && blocks[0].level == "Creature 3")
        #expect(blocks[0].entries.map(\.name) == ["Perception", "AC", "HP", "Spiteful Retort", "Speed", "Melee",
                                                  "Primal Innate Spells"])
        let creature = Fixtures.convert(blocks[0]).creature
        #expect(creature.name == "Gwibble" && creature.defenses.will == 9 && creature.strikes.count == 1)
        #expect(creature.abilities.first?.cost == .reaction)
        #expect(creature.abilities.first?.text.markup.contains("**Effect**") == true)
    }

    @Test("Blocks go to the variant for their subtier")
    func importPlan() throws {
        var scenario = Scenario(campaignID: UUID(), name: "7-99", variantLabels: ["1–2", "3–4"])
        scenario.lastVariantLabel = "1–2"
        let plan = StatBlockImport(blocks: try Fixtures.blocks(), scenario: scenario, game: .pathfinder,
                                   currentLabel: "1–2")
        #expect(plan.items.map(\.variantLabel) == ["1–2", "3–4"])
        #expect(plan.items[0].custom.subtier == "1-2" && plan.items[0].custom.scenarioID == scenario.id)
        #expect(plan.items[0].custom.creature.key == plan.items[0].custom.key)
        #expect(plan.summary == "Added Gwibble (Creature 3) and Rusty Spear Trap (Hazard 2). 1 note to review.")
        #expect(StatBlockImport.variantLabel(forSubtier: "5-6", among: ["1–2", "3–4"]) == nil)
        #expect(StatBlockImport.variantLabel(forSubtier: "1-2", among: ["Subtier 1–2"]) == "Subtier 1–2")
    }
}
