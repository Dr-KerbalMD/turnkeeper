import CombatPadKit
import Testing
@testable import FoundryImport

@Suite("Glossary import")
struct GlossaryImportTests {
    private let owner = "pf2e.test-pack.linkedCreature01"

    private func glossary() throws -> [String: GlossaryEntry] {
        let (_, links) = try Fixtures.linkedCreature()
        var parser = GlossaryEntryParser(text: Fixtures.linkingConverter(links))
        let entries = GlossaryBuilder.entries(parser: &parser)
        return Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0) })
    }

    @Test("A compendium spell has its rank, traits, details and text with links")
    func compendiumSpell() throws {
        let fear = try #require(try glossary()["pf2e.spells-srd.4koZzrnMXhhosn0D"])
        #expect(fear.name == "Fear" && fear.category == "Spell 1")
        #expect(fear.traits == ["concentrate", "emotion", "fear", "manipulate", "mental"])
        #expect(fear.links.target(.trait, "mental") == "trait.pf2e.mental")
        #expect(fear.links.target(.trait, "emotion") == nil)
        #expect(fear.text.markup.hasPrefix("""
            **Cast** {{actions:2}}; **Range** 30 feet; **Targets** 1 creature
            **Defense** Will; **Duration** varies
            ---
            You plant fear in the target.
            """))
        #expect(fear.text.markup.contains("{{link:pf2e.conditionitems.TBSHQspnbcqxsmjL|Frightened 1}}"))
    }

    @Test("A creature's own spell uses its heightened rank")
    func embeddedSpell() throws {
        let cloud = try #require(try glossary()["\(owner).spell2"])
        #expect(cloud.category == "Spell 2")
        #expect(cloud.text.markup == """
            **Cast** {{actions:1}} to {{actions:3}}
            **Duration** sustained up to 1 minute
            ---
            Spores deal {{damage:2d4|poison}} damage.
            """)
    }

    @Test("Items, abilities and traits become entries")
    func otherEntries() throws {
        let glossary = try glossary()
        let pouch = try #require(glossary["\(owner).item1"])
        #expect(pouch.category == "Item 3" && pouch.traits == ["uncommon", "fungus"])
        let grab = try #require(glossary["pf2e.bestiary-ability-glossary-srd.Tkd8sH4pwFIPzqTr"])
        #expect(grab.category == "Ability" && grab.cost == .one)
        let reach = try #require(glossary["trait.pf2e.reach"])
        #expect(reach.name == "Reach" && reach.category == "Trait")
        #expect(glossary["pf2e.conditionitems.TBSHQspnbcqxsmjL"]?.category == "Condition")
    }

    @Test("Links are followed two levels deep and no further")
    func depth() throws {
        let glossary = try glossary()
        // Creature → Fear → Frightened; Frightened → Stunned would be a third level.
        #expect(glossary["pf2e.conditionitems.TBSHQspnbcqxsmjL"] != nil)
        // Stunned is still reached in two levels, through Spore Bite.
        #expect(glossary["pf2e.conditionitems.dfCMdR4wnpbYNTix"] != nil)
        // Daze and Fireball are never linked.
        #expect(glossary["pf2e.spells-srd.4gBIw4IDrSfFHik4"] == nil)
        #expect(glossary["pf2e.spells-srd.sxQZ6yqTn0czJxVd"] == nil)
    }

    @Test("Entry categories")
    func categories() {
        func category(_ type: String, traits: [String] = [], ritual: Bool = false, id: String = "x") -> String {
            let document = JSONValue.object([
                "type": .string(type),
                "system": .object([
                    "traits": .object(["value": .array(traits.map(JSONValue.string))]),
                    "ritual": ritual ? .object([:]) : .null
                ])
            ])
            return GlossaryEntryParser.category(document, id: id, level: 4)
        }
        #expect(category("spell", traits: ["cantrip"]) == "Cantrip 4")
        #expect(category("spell", traits: ["focus"]) == "Focus 4")
        #expect(category("spell", ritual: true) == "Ritual 4")
        #expect(category("weapon") == "Item 4")
        #expect(category("feat") == "Feat 4")
        #expect(category("action", id: "pf2e.actionspf2e.a") == "Action")
        #expect(category("deity") == "Deity")
    }

    @Test("Spell details read the cast time, area and basic defense")
    func spellDetails() {
        let system = JSONValue.object([
            "time": .string("1 minute"),
            "area": .object(["type": .string("burst"), "value": .number(20)]),
            "defense": .object(["save": .object(["statistic": .string("reflex"), "basic": .bool(true)])]),
            "duration": .object(["sustained": .bool(true), "value": .string("")])
        ])
        let wrapped = JSONValue.object([
            "time": .object(["value": system["time"]]), "area": system["area"], "defense": system["defense"],
            "duration": system["duration"]
        ])
        #expect(SpellDetails.markup(wrapped) == """
            **Cast** 1 minute; **Area** 20-foot burst
            **Defense** basic Reflex; **Duration** sustained
            """)
        #expect(SpellDetails.markup(.object([:])).isEmpty)
    }
}
