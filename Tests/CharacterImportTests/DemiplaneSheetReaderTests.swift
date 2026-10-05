import CombatPadKit
import Foundation
import Testing
@testable import CharacterImport

@Suite("Reading Demiplane's character sheet PDF")
struct DemiplaneSheetReaderTests {
    /// Dr Ignatius Constaline, a level 15 human thaumaturge, as Demiplane exported him.
    private func ignatius() throws -> Creature {
        let url = try #require(Bundle.module.url(forResource: "ignatius", withExtension: "pdf",
                                                 subdirectory: "Fixtures"))
        return try DemiplaneSheetReader.sheet(fromPDF: Data(contentsOf: url), game: .pathfinder)
    }

    @Test("Identity, level and the PC-only details")
    func identity() throws {
        let sheet = try ignatius()
        #expect(sheet.name == "Dr Ignatius Constaline" && sheet.level == 15 && sheet.kind == .character)
        let url = try #require(Bundle.module.url(forResource: "ignatius", withExtension: "pdf",
                                                 subdirectory: "Fixtures"))
        #expect(try DemiplaneSheetReader.sheet(fromPDF: Data(contentsOf: url), game: nil).game == .pathfinder)
        #expect(sheet.traits.traits == ["human"] && sheet.traits.size == "Medium")
        let player = try #require(sheet.player)
        #expect(player.ancestry == "Human" && player.heritage == "Versatile Human")
        #expect(player.background == "Charlatan" && player.className == "Thaumaturge" && player.classDC == 34)
        #expect(player.feats.contains("Toughness") && player.feats.contains("Too Angry to Die"))
        #expect(player.classFeatures.first == "Mirror")
        #expect(Set(player.classFeatures).count == player.classFeatures.count)
    }

    @Test("Defenses, Perception, senses, languages and speed")
    func defenses() throws {
        let sheet = try ignatius()
        let defenses = sheet.defenses
        let values: [Int] = [defenses.armorClass, defenses.fortitude, defenses.reflex, defenses.will]
        #expect(values == [33, 24, 21, 24])
        #expect(defenses.hitPoints == 0)  // The PDF's max HP is wrong, so it isn't read.
        #expect(sheet.senses.perception == 22 && sheet.senses.senses == ["low-light vision"])
        #expect(sheet.languages == ["Common", "Sign Language"])
        #expect(sheet.speeds == [Speed(type: "land", feet: 25)])
        #expect(sheet.attributes.charisma == 5 && sheet.attributes.wisdom == 1)
    }

    @Test("Every skill, then the lores")
    func skills() throws {
        let skills = try ignatius().skills
        #expect(skills.first == Skill(name: "Acrobatics", modifier: 19))
        #expect(skills.contains(Skill(name: "Occultism", modifier: 29)))
        #expect(Array(skills.suffix(2)) == [Skill(name: "Underworld Lore", modifier: 21),
                                            Skill(name: "Esoteric Lore", modifier: 28)])
    }

    @Test("Strikes have their attack, damage type and traits; runes listed as weapons are skipped")
    func strikes() throws {
        let strikes = try ignatius().strikes
        #expect(strikes.map(\.name) == ["Dog-Bone Knife", "Hatchet", "Rapier"])
        let knife = strikes[0]
        #expect(knife.attackBonus == 26 && !knife.isRanged)
        #expect(knife.damage == [DamagePart(formula: "2d4+10", type: "piercing")])
        #expect(knife.traits == ["uncommon", "abjuration", "magical", "agile", "finesse", "thrown-10-ft",
                                 "versatile-s"])
    }

    @Test("Actions, reactions and free actions, with costs, triggers and traits")
    func abilities() throws {
        let abilities = try ignatius().abilities
        let exploit = try #require(abilities.first { $0.name == "Exploit Vulnerability" })
        #expect(exploit.cost == .one && exploit.section == .offensive)
        #expect(exploit.traits == ["esoterica", "manipulate", "thaumaturge"])
        let twin = try #require(abilities.first { $0.name == "Twin Weakness" })
        #expect(twin.cost == .two)
        let angry = try #require(abilities.first { $0.name == "Too Angry to Die" })
        #expect(angry.cost == .reaction && angry.section == .defensive)
        #expect(angry.text.markup.hasPrefix("**Trigger** you stand up from prone"))
        let bounce = try #require(abilities.first { $0.name == "Bounce Back" })
        #expect(bounce.cost == .free && bounce.section == .offensive)
    }

    @Test("Spells by rank, cantrips and innate spells")
    func spells() throws {
        let entries = try ignatius().spellcasting
        #expect(entries.map(\.name) == ["Spells", "Innate Spells"])
        let ranks = entries[0].ranks
        #expect(ranks.map(\.rank) == [3, 2, 1, 8])
        #expect(ranks[0].spells.map(\.name) == ["Roaring Applause"])
        #expect(ranks.last?.kind == .cantrips)
        #expect(ranks.last?.spells.map(\.name) == ["Musical Accompaniment", "Guidance"])
        #expect(entries[1].ranks == [SpellRank(kind: .ranked, rank: 8, spells: [SpellEntry(name: "Guidance")])])
    }

    @Test("Inventory items, without repeats")
    func items() throws {
        let items = try ignatius().items
        #expect(items.first == "Bag of Holding, I")
        #expect(items.filter { $0 == "Healing Potion, Moderate" }.count == 1)
    }

    @Test("A Starfinder sheet: Computers and Piloting, untyped damage, and range, magazine and expend")
    func starfinder() throws {
        let url = try #require(Bundle.module.url(forResource: "eagan", withExtension: "pdf", subdirectory: "Fixtures"))
        let sheet = try DemiplaneSheetReader.sheet(fromPDF: Data(contentsOf: url), game: nil)
        #expect(sheet.game == .starfinder)
        #expect(sheet.name == "Eagan Norr (v.2)" && sheet.level == 1 && sheet.player?.className == "Operative")
        #expect(sheet.defenses.armorClass == 18 && sheet.player?.classDC == 17)
        #expect(sheet.skills.contains(Skill(name: "Computers", modifier: 6)))
        #expect(sheet.skills.contains(Skill(name: "Piloting", modifier: 7)))
        let pistol = try #require(sheet.strikes.first { $0.isRanged })
        #expect(pistol.name == "Rotating Pistol" && pistol.attackBonus == 9)
        #expect(pistol.damage == [DamagePart(formula: "1d6", type: "")])
        #expect(pistol.traits == ["agile", "analog", "concealable", "concussive", "range-60-ft", "magazine-6",
                                  "expend-1"])
        #expect(sheet.strikes.filter { !$0.isRanged }.map(\.name) == ["Shield Bash", "Baton"])
        #expect(sheet.abilities.map(\.name) == ["Aim", "Sabotage", "Tactical Advance", "Mobile Aim"])
        #expect(sheet.player?.feats.first == "Natural Ambition")
    }

    @Test("Data that isn't a fillable PDF is rejected")
    func notASheet() {
        #expect(throws: CharacterImportError.self) {
            try DemiplaneSheetReader.sheet(fromPDF: Data("not a pdf".utf8), game: .pathfinder)
        }
    }

    @Test("Trait words become Foundry-style slugs, without repeats or covered bare traits")
    func traitSlugs() {
        #expect(TraitSlugs.slugs(["Deadly d8", "disarm", "deadly", "versatile P", "versatile", "disarm"])
                == ["deadly-d8", "disarm", "versatile-p"])
        #expect(TraitSlugs.slug("thrown 10 ft.") == "thrown-10-ft")
    }

    @Test("Shield, resistances, immunities, other speeds and a named caster's tradition")
    func otherFields() {
        let fields = SheetFields(values: [
            "shield_bonus": "2", "resistances": "fire 5, poison", "immunities": "sleep",
            "speed": "30", "fly_speed": "20", "tradition_occult_yn": "Yes", "prepared_caster_yn": "Yes",
            "spells_1": "Fear", "spells_rank_1": "1", "spell_dc_total": "21", "spells_ritual_1": "Commune",
            "spells_ritual_1_rank": "6", "spells_focus_1": "Hymn of Healing", "spells_focus_rank": "1"
        ])
        let sheet = DemiplaneSheetReader.sheet(from: fields, game: .starfinder)
        #expect(sheet.defenses.armorClassDetails == "+2 with shield raised")
        #expect(sheet.defenses.resistances == [DamageAdjustment(type: "fire", value: 5)])
        #expect(sheet.defenses.immunities == ["sleep"])
        #expect(sheet.speeds == [Speed(type: "land", feet: 30), Speed(type: "fly", feet: 20)])
        #expect(sheet.spellcasting.map(\.name) == ["Occult Prepared Spells", "Focus Spells", "Rituals"])
        #expect(sheet.spellcasting.allSatisfy { $0.difficultyClass == 21 })
        #expect(sheet.traits.size == "Medium" && sheet.skills.isEmpty)
    }
}
