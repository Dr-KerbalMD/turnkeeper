import Foundation
import Testing
@testable import CombatPadKit

@Suite("Glossary")
struct GlossaryTests {
    @Test("A link table finds a word's target by kind")
    func linkTable() {
        var links = LinkTable()
        links.add(.spell, "fireball", target: "pf2e.spells-srd.fire")
        links.add(.trait, "fire", target: "trait.pf2e.fire")
        #expect(links.target(.spell, "fireball") == "pf2e.spells-srd.fire")
        #expect(links.target(.item, "fireball") == nil)
        #expect(links.allTargets == ["pf2e.spells-srd.fire", "trait.pf2e.fire"])
        #expect(!links.isEmpty)
        #expect(LinkTable().isEmpty)
    }

    @Test("A link table encodes as a plain dictionary")
    func linkTableCodable() throws {
        var links = LinkTable()
        links.add(.effect, "Grab", target: "x.y")
        let data = try JSONEncoder().encode(links)
        #expect(String(data: data, encoding: .utf8) == #"{"effect:Grab":"x.y"}"#)
        #expect(try JSONDecoder().decode(LinkTable.self, from: data) == links)
    }

    @Test("Creatures saved before links existed still load")
    func creatureWithoutLinks() throws {
        let creature = Creature(key: "custom.1", name: "Goblin", game: .pathfinder)
        let data = try JSONEncoder().encode(creature)
        #expect(String(data: data, encoding: .utf8)?.contains("links") == false)
        #expect(try JSONDecoder().decode(Creature.self, from: data).links == nil)
    }

    @Test("The bestiary loads glossary entries on first use")
    func storeLoadsGlossary() throws {
        let directory = try bestiaryDirectory(glossary: [
            GlossaryEntry(id: "pf2e.conditionitems.a", name: "Frightened", category: "Condition", text: "Scared.")
        ])
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try BestiaryStore(generatedDirectory: directory)
        #expect(store.glossaryEntry("pf2e.conditionitems.a")?.name == "Frightened")
        #expect(store.glossaryEntry("missing") == nil)
    }

    @Test("A bestiary without a glossary has no entries")
    func storeWithoutGlossary() throws {
        let directory = try bestiaryDirectory(glossary: nil)
        defer { try? FileManager.default.removeItem(at: directory) }
        #expect(try BestiaryStore(generatedDirectory: directory).glossaryEntry("any") == nil)
        #expect(BestiaryStore().glossaryEntry("any") == nil)
    }

    private func bestiaryDirectory(glossary: [GlossaryEntry]?) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let bestiary = directory.appendingPathComponent("Bestiary")
        try FileManager.default.createDirectory(at: bestiary, withIntermediateDirectories: true)
        let index = BestiaryIndex(sourceRevision: "", entries: [])
        try JSONEncoder().encode(index).write(to: bestiary.appendingPathComponent("index.json"))
        if let glossary {
            try JSONEncoder().encode(glossary).write(to: bestiary.appendingPathComponent("glossary.json"))
        }
        return directory
    }
}
