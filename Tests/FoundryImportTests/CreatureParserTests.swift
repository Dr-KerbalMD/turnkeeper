import CombatPadKit
import Testing
@testable import FoundryImport

@Suite("Creature parsing")
struct CreatureParserTests {
    @Test("Goblin warrior statistics")
    func goblinWarrior() throws {
        let goblin = try Fixtures.creature("goblin-warrior", pack: "pathfinder-monster-core")
        #expect(goblin.key == "pf2e.pathfinder-monster-core.fLLKuOXwPq1Iq0U4")
        #expect(goblin.level == -1)
        #expect(goblin.traits == TraitLine(rarity: "common", size: "Small", traits: ["goblin", "humanoid"]))
        #expect(goblin.senses.perception == 2)
        #expect(goblin.senses.senses == ["darkvision"])
        #expect(goblin.languages == ["Goblin", "Common"])
        #expect(goblin.skills.map(\.name) == ["Acrobatics", "Athletics", "Nature", "Stealth"])
        #expect(goblin.attributes.dexterity == 3)
        #expect(goblin.defenses.armorClass == 16)
        #expect([goblin.defenses.fortitude, goblin.defenses.reflex, goblin.defenses.will] == [5, 7, 3])
        #expect(goblin.defenses.hitPoints == 6)
        #expect(goblin.speeds == [Speed(type: "land", feet: 25)])
        #expect(goblin.items.contains("arrows (10)"))
        #expect(goblin.source.isRemastered)
    }

    @Test("Goblin warrior Strikes and reaction")
    func goblinStrikesAndAbilities() throws {
        let goblin = try Fixtures.creature("goblin-warrior")
        let shortbow = try #require(goblin.strikes.first { $0.name == "Shortbow" })
        #expect(shortbow.isRanged)
        #expect(shortbow.attackBonus == 7)
        #expect(shortbow.traits.contains("range increment 60 feet"))
        #expect(shortbow.damage == [DamagePart(formula: "1d6", type: "piercing")])
        let scuttle = try #require(goblin.abilities.first)
        #expect(scuttle.cost == .reaction)
        #expect(scuttle.section == .defensive)
        #expect(scuttle.text.markup.contains("The goblin warrior Steps."))
    }

    @Test("Innate spells group by rank, with constant spells and uses")
    func innateSpells() throws {
        let rekhep = try Fixtures.creature("rekhep")
        let entry = try #require(rekhep.spellcasting.first)
        #expect(entry.difficultyClass == 27)
        #expect(entry.attack == 19)
        #expect(entry.ranks.map(\.kind) == entry.ranks.map(\.kind).sorted { order($0) < order($1) })
        let constant = try #require(entry.ranks.first { $0.kind == .constant })
        #expect(constant.spells.map(\.name) == ["truespeech"])
        let all = entry.ranks.flatMap(\.spells)
        #expect(all.contains(SpellEntry(name: "translocate", note: "at will")))
        #expect(all.contains(SpellEntry(name: "share life", note: "×3")))
        let pursuit = try #require(rekhep.abilities.first { $0.name == "Archon's Pursuit" })
        #expect(pursuit.frequency == "1/day")
        #expect(pursuit.isLimited)
    }

    @Test("Prepared spells come from the slots, with repeats counted")
    func preparedSpells() throws {
        let dragon = try Fixtures.creature("adamantine-dragon-young-spellcaster")
        let entry = try #require(dragon.spellcasting.first { !$0.ranks.isEmpty })
        let ranks = entry.ranks.filter { $0.kind == .ranked }.map(\.rank)
        #expect(ranks == ranks.sorted(by: >))
        #expect(entry.ranks.contains { $0.kind == .cantrips })
    }

    @Test("Starfinder Strikes, area fire and once-per-round abilities")
    func starfinderAlien() throws {
        let commander = try Fixtures.creature("aeon-guard-commander", game: .starfinder, pack: "alien-core-bestiary")
        #expect(commander.key.hasPrefix("sf2e.alien-core-bestiary."))
        let pistol = try #require(commander.strikes.first { $0.name == "Boom Pistol" })
        #expect(pistol.traits.contains("tech"))
        #expect(pistol.damage.first == DamagePart(formula: "2d6+3", type: "sonic"))
        let areaFire = try #require(commander.strikes.first { $0.name == "Area Fire" })
        #expect(areaFire.areaNote == "area fire (10-foot burst)")
        let tactical = try #require(commander.abilities.first { $0.name == "Tactical Strike" })
        #expect(tactical.isLimited)
        #expect(!commander.abilities.contains { $0.text.markup.contains("Effect: ") })
    }

    @Test("Complex hazards are imported with their hazard text; simple ones are skipped")
    func hazards() throws {
        let pit = try Fixtures.creature("drowning-pit")
        #expect(pit.kind == .hazard)
        #expect(pit.initiativeStatistic == "stealth")
        let details = try #require(pit.hazard)
        #expect(details.stealth == 10)
        #expect(details.disable.markup.contains("{{check:thievery:18}}"))
        #expect(!details.routine.isEmpty)
        #expect(pit.defenses.hardness == 15)
        var parser = CreatureParser(text: Fixtures.converter())
        #expect(parser.creature(from: try Fixtures.document("simple-hazard"), game: .pathfinder, pack: "x") == nil)
    }

    private func order(_ kind: SpellRank.Kind) -> Int {
        [SpellRank.Kind.ranked: 0, .cantrips: 1, .constant: 2][kind] ?? 0
    }
}
