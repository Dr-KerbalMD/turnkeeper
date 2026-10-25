import Foundation
import Testing
@testable import TurnkeeperKit

@Suite("Challenge points")
struct ChallengePointsTests {
    @Test("Points by level above the lowest allowed", arguments: [(1, 2), (2, 3), (3, 4), (4, 6), (0, 2), (7, 6)])
    func points(level: Int, expected: Int) {
        #expect(ChallengePoints.points(forLevel: level, lowestAllowed: 1) == expected)
    }

    @Test("The rules' example: levels 1, 2, 3, 4 and 4 at a 1–4 table give 21")
    func example() {
        #expect(ChallengePoints.total(levels: [1, 2, 3, 4, 4], lowestAllowed: 1) == 21)
    }

    @Test("Level ranges and labels are read loosely")
    func parsing() {
        #expect(ChallengePoints.lowestLevel(in: "3–6") == 3)
        #expect(ChallengePoints.lowestLevel(in: "levels 5 to 8") == 5)
        #expect(ChallengePoints.lowestLevel(in: "") == nil)
        #expect(ChallengePoints.range(of: "16–18 CP") == 16...18)
        #expect(ChallengePoints.range(of: "19-22") == 19...22)
        #expect(ChallengePoints.range(of: "33+ CP")?.contains(40) == true)
        #expect(ChallengePoints.range(of: "Harder") == nil)
    }

    @Test("The total picks the label whose range holds it")
    func matching() {
        let low = VariantScheme.challengePointsLowTier.labels
        #expect(ChallengePoints.label(for: 15, among: low) == "14–15 CP")
        #expect(ChallengePoints.label(for: 9, among: low) == nil)
        #expect(ChallengePoints.label(for: 35, among: VariantScheme.challengePointsHighTier.labels) == "33+ CP")
    }

    @Test("A party's points count present players, at their own level or the party's")
    func party() {
        var veteran = PartyMember(name: "Kyra")
        veteran.level = 4
        var away = PartyMember(name: "Ezren")
        away.isAway = true
        let party = Party(campaignID: UUID(), name: "Table", level: 1,
                          members: [PartyMember(name: "Valeros"), veteran, away])
        #expect(party.challengePoints(levelRange: "1–4") == 8)
        #expect(party.challengePoints(levelRange: "") == nil)
    }

    @Test("Starfinder's points: 2 at the lower level or below, 3 at the higher level or above",
          arguments: [(0, 2), (1, 2), (2, 3), (5, 3)])
    func starfinderPoints(level: Int, expected: Int) {
        #expect(StarfinderDifficulty.points(forLevel: level, lowestAllowed: 1) == expected)
    }

    @Test("Starfinder's tables: up to 10 points Easier, 11–14 Base, 15 or more Harder",
          arguments: [([1, 1, 1, 1], "Easier"), ([1, 1, 1, 1, 1], "Easier"), ([2, 2, 2, 2], "Base"),
                      ([1, 1, 1, 1, 1, 1], "Base"), ([2, 2, 2, 2, 2], "Harder"), ([2, 2, 2, 2, 2, 2], "Harder"),
                      ([1, 1, 2, 2], "Easier"), ([1, 2, 2, 2], "Base")])
    func starfinderTables(levels: [Int], expected: String) {
        #expect(StarfinderDifficulty.label(for: StarfinderDifficulty.total(levels: levels, lowestAllowed: 1))
                == expected)
    }

    @Test("A scenario picks its difficulty by its labels' scheme")
    func scenarioPicks() {
        let party = Party(campaignID: UUID(), name: "Table", level: 2,
                          members: (1...4).map { PartyMember(name: "PC \($0)") })
        var starfinder = Scenario(campaignID: UUID(), name: "#1-01",
                                  variantLabels: VariantScheme.easierBaseHarder.labels)
        starfinder.levelRange = "1-2"
        #expect(starfinder.pointScheme == .starfinder)
        #expect(starfinder.difficulty(for: party) == DifficultyPick(points: 12, pointsText: "12 points", label: "Base"))
        var pathfinder = Scenario(campaignID: UUID(), name: "#6-01",
                                  variantLabels: VariantScheme.challengePointsLowTier.labels)
        pathfinder.levelRange = "1-4"
        #expect(pathfinder.difficulty(for: party) == DifficultyPick(points: 12, pointsText: "12 CP", label: "12–13 CP"))
        let single = Scenario(campaignID: UUID(), name: "Quest", variantLabels: VariantScheme.single.labels)
        #expect(single.pointScheme == nil && single.difficulty(for: party) == nil)
        starfinder.levelRange = ""
        #expect(starfinder.difficulty(for: party) == nil)
    }

    @Test("A new encounter opens at Base; one with a plan opens at the difficulty last run")
    func startingVariant() {
        let scenario = Scenario(campaignID: UUID(), name: "#7-01",
                                variantLabels: VariantScheme.easierBaseHarder.labels)
        var encounter = Encounter(scenarioID: scenario.id, name: "Docks")
        #expect(scenario.startingVariantLabel(for: encounter, lastRun: "Harder") == "Base")
        var easier = encounter.variant("Easier")
        easier.slots = [EncounterSlot(creatureKey: "goblin")]
        encounter.setVariant(easier)
        #expect(scenario.startingVariantLabel(for: encounter, lastRun: "Harder") == "Harder")
        #expect(scenario.startingVariantLabel(for: encounter, lastRun: "") == "Base")
        let tiers = Scenario(campaignID: UUID(), name: "#6-01",
                             variantLabels: VariantScheme.challengePointsLowTier.labels)
        #expect(tiers.startingVariantLabel(for: encounter, lastRun: "") == "10–11 CP")
    }
}
