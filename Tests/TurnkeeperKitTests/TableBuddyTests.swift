import Bestiary
import Foundation
import Testing
@testable import TurnkeeperKit

/// Pregens at levels 1, 3 and 5 (and 7 for Valeros), with their level as their AC so tests can tell sheets apart.
private struct FakePregens: PregenSource {
    func levels(of key: String) -> [Int] {
        ["ezren": [1, 3, 5], "valeros": [1, 3, 5, 7]][key] ?? []
    }

    func pregen(_ key: String, level: Int) -> Pregen? {
        guard levels(of: key).contains(level) else { return nil }
        var sheet = Creature(key: "", name: key.capitalized, game: .pathfinder)
        sheet.level = level
        sheet.defenses.armorClass = level
        return Pregen(key: key, name: key.capitalized, level: level, sheet: sheet, hitPoints: level * 10)
    }
}

@Suite("Table Buddies")
struct TableBuddyTests {
    /// Real PCs at these levels, and Ezren added as a Table Buddy.
    private func table(_ levels: [Int], partyLevel: Int = 3) -> Party {
        var party = Party(campaignID: UUID(), name: "Table", level: partyLevel)
        party.members = levels.enumerated().map { index, level in
            var member = PartyMember(name: "PC \(index + 1)")
            member.level = level
            return member
        }
        party.addTableBuddy("ezren", from: FakePregens())
        return party
    }

    private func ezren(_ party: Party) -> PartyMember? {
        party.members.first(where: \.isTableBuddy)
    }

    @Test("The Guide's Adding Pregens table: Base Level, real PCs and their challenge points pick the level")
    func guideTable() {
        // Base Level 1: two PCs under 8 CP get level 1 pregens, 8 or more level 3; three PCs switch at 12.
        #expect(PregenLevel.pathfinder(baseLevel: 1, realLevels: [2, 3]) == 1)  // 3 + 4 = 7
        #expect(PregenLevel.pathfinder(baseLevel: 1, realLevels: [3, 3]) == 3)  // 8
        #expect(PregenLevel.pathfinder(baseLevel: 1, realLevels: [2, 2, 3]) == 1)  // 10
        #expect(PregenLevel.pathfinder(baseLevel: 1, realLevels: [2, 2, 4]) == 3)  // 12
        #expect(PregenLevel.pathfinder(baseLevel: 3, realLevels: [3, 5]) == 3)  // 6
        #expect(PregenLevel.pathfinder(baseLevel: 3, realLevels: [5, 5]) == 5)  // 8
        #expect(PregenLevel.pathfinder(baseLevel: 3, realLevels: [4, 4, 5]) == 3)  // 10
        #expect(PregenLevel.pathfinder(baseLevel: 3, realLevels: [5, 5, 5]) == 5)  // 12
        #expect(PregenLevel.pathfinder(baseLevel: 5, realLevels: [5, 5]) == 5)
        #expect(PregenLevel.pathfinder(baseLevel: 5, realLevels: [8, 8, 8]) == 5)
        #expect(PregenLevel.pathfinder(baseLevel: 7, realLevels: [7, 7, 7]) == nil)
    }

    @Test("A pregen plays at its highest level at or below the wanted one, else its lowest")
    func availableLevels() {
        #expect(PregenLevel.available(4, among: [1, 3, 5]) == 3)
        #expect(PregenLevel.available(9, among: [1, 3, 5, 7]) == 7)
        #expect(PregenLevel.available(9, among: [1, 3, 5]) == 5)
        #expect(PregenLevel.available(0, among: [1, 3, 5]) == 1)
        #expect(PregenLevel.available(3, among: []) == nil)
    }

    @Test("Adding one gives a linked member at the party's level, with the pregen's sheet and max HP")
    func adding() throws {
        let party = table([], partyLevel: 4)
        let member = try #require(ezren(party))
        #expect(member.name == "Ezren" && member.level == 3 && member.maxHitPoints == 30)
        #expect(member.link?.source == .pregen && member.link?.characterID == "ezren")
        #expect(member.sheet?.defenses.armorClass == 3)
        var noSuch = party
        #expect(noSuch.addTableBuddy("nobody", from: FakePregens()) == nil)
    }

    @Test("A 1–4 scenario with two PCs at 12 CP gets Ezren at level 3, who adds 4 CP")
    func settlingForAScenario() throws {
        let party = table([4, 4], partyLevel: 1)
        let settled = party.settlingTableBuddies(game: .pathfinder, levelRange: "1–4", source: FakePregens())
        #expect(ezren(settled)?.level == 3 && ezren(settled)?.sheet?.defenses.armorClass == 3)
        #expect(settled.challengePoints(levelRange: "1–4") == 16)
        let small = table([2, 2], partyLevel: 3)
            .settlingTableBuddies(game: .pathfinder, levelRange: "1–4", source: FakePregens())
        #expect(ezren(small)?.level == 1)
    }

    @Test("Starfinder pregens match the band's lower level; without levels they match the party")
    func starfinderAndNoScenario() {
        let party = table([4, 4], partyLevel: 5)
        #expect(ezren(party.settlingTableBuddies(game: .starfinder, levelRange: "3–4", source: FakePregens()))?.level
                == 3)
        #expect(ezren(party.settlingTableBuddies(game: .pathfinder, levelRange: "", source: FakePregens()))?.level
                == 5)
    }

    @Test("At level 7 and up the Guide allows no pregens, so they don't count toward challenge points")
    func highLevel() {
        let party = table([7, 8, 9], partyLevel: 7)
        #expect(!party.allowsTableBuddies(game: .pathfinder, levelRange: "7–10"))
        let counted = party.countingTableBuddies(game: .pathfinder, levelRange: "7–10", source: FakePregens())
        #expect(counted.presentTableBuddies.isEmpty && counted.presentMembers.count == 3)
        #expect(party.allowsTableBuddies(game: .starfinder, levelRange: "7–8"))
    }

    @Test("Settling keeps the player's name and notes, and doesn't touch a member already at that level")
    func keepsEdits() throws {
        var party = table([4, 4], partyLevel: 1)
        let index = try #require(party.members.firstIndex { $0.isTableBuddy })
        party.members[index].playerName = "Sam"
        party.members[index].notes = "Discord: sam"
        let settled = party.settlingTableBuddies(game: .pathfinder, levelRange: "1–4", source: FakePregens())
        #expect(ezren(settled)?.playerName == "Sam" && ezren(settled)?.notes == "Discord: sam")
        let again = settled.settlingTableBuddies(game: .pathfinder, levelRange: "1–4", source: FakePregens())
        #expect(again == settled)
    }
}
