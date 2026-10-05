import CombatPadKit
import Testing
@testable import FoundryImport

@Suite("Glossary links")
struct LinkResolverTests {
    @Test("A compendium link by name or ID becomes a link run")
    func compendiumLinks() throws {
        let links = try Fixtures.links()
        var converter = Fixtures.linkingConverter(links)
        let byName = converter.convert("@UUID[Compendium.pf2e.conditionitems.Item.Frightened]{Frightened 1}").markup
        let byID = converter.convert("@UUID[Compendium.pf2e.spells-srd.Item.4gBIw4IDrSfFHik4]").markup
        #expect(byName == "{{link:pf2e.conditionitems.TBSHQspnbcqxsmjL|Frightened 1}}")
        #expect(byID == "{{link:pf2e.spells-srd.4gBIw4IDrSfFHik4|Daze}}")
        #expect(links.takeLinked() == ["pf2e.conditionitems.TBSHQspnbcqxsmjL", "pf2e.spells-srd.4gBIw4IDrSfFHik4"])
        #expect(links.takeLinked().isEmpty)
    }

    @Test("Links that lead nowhere, or to effects, stay labels")
    func unresolvedLinks() throws {
        let links = try Fixtures.links()
        var converter = Fixtures.linkingConverter(links)
        #expect(converter.convert("@UUID[Compendium.pf2e.conditionitems.Item.Fleeing]").markup == "Fleeing")
        #expect(converter.convert("@UUID[Compendium.pf2e.spell-effects.Item.Gqy7K6FnbLtwGpud]{Bless}").markup
            == "Bless")
        #expect(converter.convert("@UUID[Compendium.pf2e.journals.JournalEntry.abc]{Rules}").markup == "Rules")
        #expect(converter.convert("@UUID[Compendium.pf2e.missing-pack.Item.abc]{Gone}").markup == "Gone")
        #expect(links.takeLinked().isEmpty)
    }

    @Test("Traits link to their own description or the one of the trait without its value")
    func traits() throws {
        let links = try Fixtures.links()
        #expect(links.link(trait: "agile", game: .pathfinder) == "trait.pf2e.agile")
        #expect(links.link(trait: "reach-10", game: .pathfinder) == "trait.pf2e.reach")
        #expect(links.link(trait: "cold-iron", game: .pathfinder) == "trait.pf2e.cold-iron")
        #expect(links.link(trait: "range increment 30 feet", game: .pathfinder) == nil)
        #expect(links.link(trait: "unknown", game: .pathfinder) == nil)
        #expect(links.takeLinked() == ["trait.pf2e.agile", "trait.pf2e.cold-iron", "trait.pf2e.reach"])
    }

    @Test("Starfinder trait text prefers the Starfinder overrides")
    func starfinderTraits() throws {
        let links = try Fixtures.links()
        #expect(links.traits.description(of: "reach", game: .starfinder) == "Starfinder reach.")
        #expect(links.traits.description(of: "reach", game: .pathfinder).hasPrefix("Natural attacks"))
        #expect(links.traits.description(of: "unknown", game: .pathfinder).isEmpty)
    }

    @Test("Each ID leads to its document, trait or embedded item")
    func sources() throws {
        let links = try Fixtures.links()
        let item = JSONValue.object(["_id": .string("item1"), "name": .string("Sword")])
        let embedded = links.link(embedded: item, owner: "pf2e.pack.goblin")
        #expect(embedded == "pf2e.pack.goblin.item1")
        guard case let .document(document, game) = links.source(of: embedded) else {
            Issue.record("No embedded item")
            return
        }
        #expect(document["name"].string == "Sword" && game == .pathfinder)
        guard case let .document(fear, _) = links.source(of: "pf2e.spells-srd.4koZzrnMXhhosn0D") else {
            Issue.record("No compendium document")
            return
        }
        #expect(fear["name"].string == "Fear")
        guard case let .trait(slug, traitGame) = links.source(of: "trait.sf2e.reach") else {
            Issue.record("No trait")
            return
        }
        #expect(slug == "reach" && traitGame == .starfinder)
        #expect(isMissing(links.source(of: "pf2e.spells-srd.nothing")))
        #expect(isMissing(links.source(of: "trait.xx.reach")))
    }

    @Test("Glossary abilities are found by name")
    func packByName() throws {
        let links = try Fixtures.links()
        #expect(links.link(pack: "pf2e.bestiary-ability-glossary-srd", name: "Grab")
            == "pf2e.bestiary-ability-glossary-srd.Tkd8sH4pwFIPzqTr")
        #expect(links.link(pack: "pf2e.bestiary-ability-glossary-srd", name: "Push") == nil)
    }

    @Test("Description keys are read from every descriptions object in traits.ts")
    func descriptionKeys() {
        let source = """
        const aDescriptions = {
            "cold-iron": "PF2E.ColdIron",
        };
        const traitDescriptions = {
            ...aDescriptions,
            agile: "PF2E.Agile",
        };
        const traitNames = { fire: "PF2E.Fire" };
        """
        #expect(TraitGlossary.descriptionKeys(in: source) == ["cold-iron": "PF2E.ColdIron", "agile": "PF2E.Agile"])
    }

    private func isMissing(_ source: LinkResolver.Source) -> Bool {
        if case .missing = source { return true }
        return false
    }
}
