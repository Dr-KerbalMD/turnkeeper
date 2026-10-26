import Bestiary
import CharacterImport
import TurnkeeperKit
import Foundation

/// Table Buddies: iconic pregens added to fill out a small table, at the level the Society rules call for.
extension AppModel {
    /// The pregens for the campaign's game, for the Add Table Buddy menu.
    var tableBuddyChoices: [PregenCatalog.Character] { pregens.characters(for: game) }

    /// Adds a pregen to the party, with its Community Use portrait as the card's art.
    func addTableBuddy(_ key: String, to partyID: UUID) async {
        guard var party = party(partyID), let memberID = party.addTableBuddy(key, from: linkedPregens) else { return }
        library.save(party)
        guard let url = pregenArtURL(key), let data = try? Data(contentsOf: url) else { return }
        await setArtwork(data, for: PlayerCharacter.key(memberID: memberID))
    }

    /// A pregen's portrait in the bundled `Generated/Pregens/Art`, if it has one.
    func pregenArtURL(_ key: String) -> URL? {
        BestiaryStore.locateGeneratedDirectory()?.appendingPathComponent("Pregens/Art/\(key).png")
    }

    /// The party with its Table Buddies at the scenario's level, as its challenge points count them: left out
    /// where the Guide allows none.
    func countingTableBuddies(_ party: Party, in scenario: Scenario) -> Party {
        party.countingTableBuddies(game: game, levelRange: scenario.levelRange, source: linkedPregens)
    }

    /// Saves the party with its Table Buddies at the scenario's level, so their battle cards match the fight.
    func settleTableBuddies(_ party: Party, in scenario: Scenario) -> Party {
        let settled = party.settlingTableBuddies(game: game, levelRange: scenario.levelRange, source: linkedPregens)
        if settled != party { library.save(settled) }
        return self.party(party.id) ?? settled
    }

    /// The pregens, with their spells, abilities and items linked to the rules like a Demiplane sheet's.
    private var linkedPregens: LinkedPregens { LinkedPregens(catalog: pregens, glossary: bestiary) }
}

/// A pregen catalog whose sheets come linked to the glossary.
private struct LinkedPregens: PregenSource {
    let catalog: PregenCatalog
    let glossary: BestiaryStore

    func levels(of key: String) -> [Int] { catalog.levels(of: key) }

    func pregen(_ key: String, level: Int) -> Pregen? {
        guard var pregen = catalog.pregen(key, level: level) else { return nil }
        let linked = CharacterGlossaryLinker(glossary: glossary).link(pregen.sheet)
        pregen.sheet = linked.sheet
        pregen.linkedNames = linked.linkedNames
        pregen.totalNames = linked.totalNames
        return pregen
    }
}
