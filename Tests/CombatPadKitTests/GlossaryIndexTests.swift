import Foundation
import Testing
@testable import CombatPadKit

@Suite("Glossary index")
struct GlossaryIndexTests {
    @Test("Names are normalized: case, apostrophes and punctuation")
    func normalize() {
        #expect(GlossaryIndex.normalize("Healing Potion, Moderate") == "healing potion moderate")
        #expect(GlossaryIndex.normalize("Healing Potion (Moderate)") == "healing potion moderate")
        #expect(GlossaryIndex.normalize("Rabbit’s Foot") == "rabbits foot")
        #expect(GlossaryIndex.normalize("  Dog-Bone   Knife ") == "dog bone knife")
    }

    @Test("The first ID recorded for a name wins")
    func firstWins() {
        var index = GlossaryIndex()
        index.add(game: .pathfinder, kind: .ability, name: "Toughness", id: "remastered")
        index.add(game: .pathfinder, kind: .ability, name: "toughness", id: "legacy")
        #expect(index.id(game: .pathfinder, kind: .ability, name: "TOUGHNESS") == "remastered")
        #expect(index.count == 1)
    }

    @Test("Lookups are per game and kind")
    func scoped() {
        var index = GlossaryIndex()
        index.add(game: .pathfinder, kind: .spell, name: "Guidance", id: "pf")
        #expect(index.id(game: .starfinder, kind: .spell, name: "Guidance") == nil)
        #expect(index.id(game: .pathfinder, kind: .item, name: "Guidance") == nil)
    }

    @Test("The index round-trips as a plain dictionary")
    func coding() throws {
        var index = GlossaryIndex()
        index.add(game: .starfinder, kind: .trait, name: "analog", id: "trait.sf2e.analog")
        let data = try JSONEncoder().encode(index)
        #expect(String(data: data, encoding: .utf8) == #"{"sf2e:trait:analog":"trait.sf2e.analog"}"#)
        #expect(try JSONDecoder().decode(GlossaryIndex.self, from: data) == index)
    }
}
