import CombatPadKit
import Testing
@testable import FoundryImport

@Suite("Creature links")
struct CreatureLinkerTests {
    private let owner = "pf2e.test-pack.linkedCreature01"

    private func linkedCreature() throws -> (Creature, LinkResolver) {
        try Fixtures.linkedCreature()
    }

    @Test("Spells link to their compendium source, else to the creature's own copy when it has text")
    func spells() throws {
        let links = try #require(try linkedCreature().0.links)
        #expect(links.target(.spell, "fear") == "pf2e.spells-srd.4koZzrnMXhhosn0D")
        #expect(links.target(.spell, "spore cloud") == "\(owner).spell2")
        #expect(links.target(.spell, "mystery") == nil)
    }

    @Test("Items, Strike effects and traits are linked as the card shows them")
    func itemsEffectsAndTraits() throws {
        let links = try #require(try linkedCreature().0.links)
        #expect(links.target(.item, "spore pouch (2)") == "\(owner).item1")
        #expect(links.target(.effect, "Spore Bite") == "\(owner).action1")
        #expect(links.target(.effect, "grab") == "pf2e.bestiary-ability-glossary-srd.Tkd8sH4pwFIPzqTr")
        #expect(links.target(.effect, "push") == nil)
        #expect(links.target(.trait, "fungus") == "trait.pf2e.fungus")
        #expect(links.target(.trait, "reach-10") == "trait.pf2e.reach")
        #expect(links.target(.trait, "mental") == "trait.pf2e.mental")
        #expect(links.target(.trait, "unknown-trait") == nil)
    }

    @Test("A creature with nothing to link has no link table")
    func noLinks() throws {
        let document = JSONValue.object(["_id": .string("bare"), "name": .string("Bare"), "type": .string("npc")])
        var parser = CreatureParser(text: Fixtures.linkingConverter(try Fixtures.links()))
        let creature = parser.creature(from: document, game: .pathfinder, pack: "test-pack")
        #expect(creature != nil && creature?.links == nil)
    }
}
