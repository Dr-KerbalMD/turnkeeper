import Bestiary
import Foundation
import Testing
@testable import CombatPadKit

@Suite("Linking a character sheet to the glossary")
struct CharacterGlossaryLinkerTests {
    /// A glossary with a few Pathfinder names and their entries.
    private struct FakeGlossary: GlossarySource {
        var index = GlossaryIndex()
        var entries: [String: GlossaryEntry] = [:]

        init() {
            add(.spell, "Guidance", "spell.guidance")
            add(.item, "Healing Potion (Moderate)", "item.potion")
            add(.item, "Rapier", "item.rapier")
            add(.ability, "Toughness", "feat.toughness")
            add(.ability, "Exploit Vulnerability", "action.exploit", text: "You scour your memories.")
            add(.item, "Rapier", "sf.rapier", game: .starfinder)
            add(.item, "Rotating Pistol", "sf.pistol", game: .starfinder)
            add(.ability, "Bounce Back", "feat.bounce")
            for trait in ["agile", "thrown", "deadly", "versatile p"] {
                add(.trait, trait, "trait.pf2e.\(trait.replacingOccurrences(of: " ", with: "-"))")
            }
        }

        private mutating func add(
            _ kind: GlossaryIndex.Kind, _ name: String, _ id: String, game: Game = .pathfinder, text: RulesText = ""
        ) {
            index.add(game: game, kind: kind, name: name, id: id)
            entries[id] = GlossaryEntry(id: id, name: name, category: "Test", text: text)
        }

        func glossaryID(game: Game, kind: GlossaryIndex.Kind, name: String) -> String? {
            index.id(game: game, kind: kind, name: name)
        }

        func glossaryEntry(_ id: String) -> GlossaryEntry? { entries[id] }
    }

    private func sheet() -> Creature {
        var sheet = Creature(key: "", name: "Ignatius", game: .pathfinder)
        let cantrips = SpellRank(kind: .cantrips, rank: 8, spells: [SpellEntry(name: "Guidance"),
                                                                  SpellEntry(name: "Unknown Cantrip")])
        sheet.spellcasting = [Spellcasting(name: "Innate Spells", difficultyClass: 0, attack: 0, ranks: [cantrips])]
        sheet.items = ["Healing Potion, Moderate", "Bag of Holding, I"]
        sheet.strikes = [Strike(name: "Rapier", isRanged: false, attackBonus: 25, traits: ["deadly-d8", "agile"],
                                damage: [])]
        var exploit = Ability(name: "Exploit Vulnerability", cost: .one, section: .offensive, text: "PDF text.")
        exploit.traits = ["thrown-10-ft"]
        let bounce = Ability(name: "Bounce Back", cost: .free, section: .defensive, text: "PDF text.")
        sheet.abilities = [exploit, bounce]
        var player = PlayerDetails()
        player.feats = ["Toughness", "Bounce Back", "Homebrew Feat"]
        sheet.player = player
        return sheet
    }

    private func linked() -> LinkedSheet {
        CharacterGlossaryLinker(glossary: FakeGlossary()).link(sheet())
    }

    @Test("Spells, items, Strikes, feats and abilities are linked by name; unknown names aren't")
    func names() throws {
        let links = try #require(linked().sheet.links)
        #expect(links.target(.spell, "Guidance") == "spell.guidance")
        #expect(links.target(.spell, "Unknown Cantrip") == nil)
        #expect(links.target(.item, "Healing Potion, Moderate") == "item.potion")
        #expect(links.target(.item, "Bag of Holding, I") == nil)
        #expect(links.target(.item, "Rapier") == "item.rapier")
        #expect(links.target(.ability, "Toughness") == "feat.toughness")
        #expect(links.target(.ability, "Homebrew Feat") == nil)
    }

    @Test("Each name counts once towards the tally")
    func tally() {
        let result = linked()
        // Guidance, the potion, Rapier, Toughness, Bounce Back and Exploit Vulnerability, of 9 distinct names.
        #expect(result.linkedNames == 6 && result.totalNames == 9)
    }

    @Test("An ability shows its glossary entry's text when the entry has some, else the sheet's")
    func abilityText() {
        let abilities = linked().sheet.abilities
        #expect(abilities[0].text == "You scour your memories.")
        #expect(abilities[1].text == "PDF text.")
    }

    @Test("Traits link by their longest leading words with an entry")
    func traits() throws {
        let links = try #require(linked().sheet.links)
        #expect(links.target(.trait, "deadly-d8") == "trait.pf2e.deadly")
        #expect(links.target(.trait, "thrown-10-ft") == "trait.pf2e.thrown")
        #expect(links.target(.trait, "agile") == "trait.pf2e.agile")
    }

    @Test("A Starfinder character prefers Starfinder names, then falls back to Pathfinder's")
    func starfinderFallsBack() throws {
        var starfinder = sheet()
        starfinder.game = .starfinder
        let links = try #require(CharacterGlossaryLinker(glossary: FakeGlossary()).link(starfinder).sheet.links)
        #expect(links.target(.item, "Rapier") == "sf.rapier")
        #expect(links.target(.ability, "Toughness") == "feat.toughness")
        #expect(links.target(.trait, "agile") == "trait.pf2e.agile")
    }

    @Test("A Pathfinder character never takes Starfinder names")
    func pathfinderStaysPut() throws {
        var pathfinder = sheet()
        pathfinder.items = ["Rotating Pistol"]
        let links = try #require(CharacterGlossaryLinker(glossary: FakeGlossary()).link(pathfinder).sheet.links)
        #expect(links.target(.item, "Rotating Pistol") == nil && links.target(.item, "Rapier") == "item.rapier")
    }
}
