import CombatPadKit
import Testing
@testable import FoundryImport

@Suite("Player compendium")
struct PlayerCompendiumTests {
    private func linked() throws -> (GlossaryIndex, [GlossaryEntry]) {
        let repository = try Fixtures.repository()
        let links = try Fixtures.links()
        var index = try PlayerCompendium.link(scanner: PackScanner(repository: repository), links: links)
        var parser = GlossaryEntryParser(text: Fixtures.linkingConverter(links))
        let glossary = GlossaryBuilder.entries(parser: &parser)
        PlayerCompendium.addTraits(of: glossary, to: &index)
        return (index, glossary)
    }

    @Test("Every document in a player pack becomes a glossary entry")
    func entries() throws {
        let ids = Set(try linked().1.map(\.id))
        #expect(ids.isSuperset(of: [
            "pf2e.spells-srd.4gBIw4IDrSfFHik4", "pf2e.feats-srd.AmP0qu7c5dlBSath", "pf2e.feats-srd.LegacyToughness0"
        ]))
    }

    @Test("Packs outside the player packs aren't linked")
    func otherPacks() throws {
        let (index, glossary) = try linked()
        #expect(!glossary.contains { $0.id.hasPrefix("pf2e.spell-effects.") })
        #expect(index.id(game: .pathfinder, kind: .ability, name: "Grab") == nil)
    }

    @Test("Names are indexed by kind, normalized")
    func names() throws {
        let index = try linked().0
        #expect(index.id(game: .pathfinder, kind: .spell, name: "DAZE") == "pf2e.spells-srd.4gBIw4IDrSfFHik4")
        #expect(index.id(game: .pathfinder, kind: .ability, name: "Daze") == nil)
        #expect(index.id(game: .starfinder, kind: .spell, name: "Daze") == nil)
    }

    @Test("A remastered document wins a name clash")
    func remasterWins() throws {
        let index = try linked().0
        #expect(index.id(game: .pathfinder, kind: .ability, name: "toughness") == "pf2e.feats-srd.AmP0qu7c5dlBSath")
    }

    @Test("Linked traits are indexed by their slug")
    func traits() throws {
        let index = try linked().0
        #expect(index.id(game: .pathfinder, kind: .trait, name: "mental") == "trait.pf2e.mental")
    }

    @Test("Document types map to index kinds")
    func kinds() {
        #expect(PlayerCompendium.kind(of: "spell") == .spell)
        #expect(PlayerCompendium.kind(of: "heritage") == .ability)
        #expect(PlayerCompendium.kind(of: "weapon") == .item)
        #expect(PlayerCompendium.kind(of: "effect") == nil)
    }
}
