import Bestiary
import Foundation
import Testing
@testable import CharacterImport

@Suite("Iconic pregens exported from Foundry")
struct PregenTests {
    /// The exported files the app bundles.
    private static let catalog = PregenCatalog(folder: URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Resources/Pregens"))

    @Test("Both games' pregens load, by name, without the companions")
    func catalog() {
        let pathfinder = Self.catalog.characters(for: .pathfinder)
        let starfinder = Self.catalog.characters(for: .starfinder)
        #expect(pathfinder.contains { $0.key == "ezren" && $0.className == "Wizard" })
        #expect(starfinder.map(\.key).sorted() == ["chk-chk", "dae", "iseph", "navasi", "obozaya", "zemir"])
        #expect(!pathfinder.contains { ["droogami", "whirp"].contains($0.key) })
        #expect(pathfinder.map(\.name) == pathfinder.map(\.name).sorted())
        #expect(Self.catalog.levels(of: "ezren") == [1, 3, 5] && Self.catalog.levels(of: "valeros") == [1, 3, 5, 7])
        #expect(Self.catalog.pregen("ezren", level: 2) == nil && PregenCatalog().levels(of: "ezren").isEmpty)
    }

    @Test("Ezren at level 3 reads as Foundry worked him out")
    func ezren() throws {
        let pregen = try #require(Self.catalog.pregen("ezren", level: 3))
        let sheet = pregen.sheet
        #expect(pregen.name == "Ezren" && pregen.hitPoints == 32 && sheet.kind == .character && sheet.level == 3)
        #expect(sheet.defenses.armorClass == 17 && sheet.defenses.will == 8 && sheet.senses.perception == 6)
        #expect(sheet.skills.first { $0.name == "Arcana" }?.modifier == 11)
        #expect(sheet.skills.contains { $0.name == "Mercantile Lore" })
        #expect(sheet.player?.className == "Wizard" && sheet.player?.classDC == 19)
        let staff = try #require(sheet.strikes.first { $0.name == "+1 Staff" })
        #expect(staff.attackBonus == 6 && staff.damage == [DamagePart(formula: "1d4", type: "bludgeoning")])
        let arcane = try #require(sheet.spellcasting.first { $0.name == "Arcane Prepared Spells" })
        #expect(arcane.difficultyClass == 19 && arcane.attack == 9)
        #expect(arcane.ranks.last?.kind == .cantrips && arcane.ranks.last?.rank == 2)
        #expect(sheet.traits.size == "Medium" && sheet.game == .pathfinder)
    }

    @Test("Dae is a Starfinder solarian with her reactions among the defenses")
    func dae() throws {
        let sheet = try #require(Self.catalog.pregen("dae", level: 1)).sheet
        #expect(sheet.game == .starfinder && sheet.player?.className == "Solarian")
        let surge = try #require(sheet.abilities.first { $0.name == "Nimbus Surge" })
        #expect(surge.cost == .reaction && surge.section == .defensive)
        #expect(sheet.abilities.contains { $0.name == "Stellar Rush" && $0.cost == .two })
    }

    @Test("Damage formulas add up their constants and keep persistent damage apart")
    func damage() {
        #expect(DamageFormula.parts("1d4 + 1 + 2 piercing") == [DamagePart(formula: "1d4+3", type: "piercing")])
        #expect(DamageFormula.parts("1d6 - 1 bludgeoning") == [DamagePart(formula: "1d6-1", type: "bludgeoning")])
        #expect(DamageFormula.parts("(2d8 + 1 + 4) fire + 3 persistent fire") == [
            DamagePart(formula: "2d8+5", type: "fire"), DamagePart(formula: "3", type: "fire", isPersistent: true)
        ])
        #expect(DamageFormula.parts("(1 + 1) acid + 1d6 persistent acid") == [
            DamagePart(formula: "2", type: "acid"), DamagePart(formula: "1d6", type: "acid", isPersistent: true)
        ])
        #expect(DamageFormula.parts("special") == [DamagePart(formula: "special", type: "")])
    }
}
