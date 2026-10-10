import Bestiary
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

@Suite("Planning stat blocks from Pluck")
struct StatBlockImportTests {
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
