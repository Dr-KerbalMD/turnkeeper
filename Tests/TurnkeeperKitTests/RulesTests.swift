import Testing
@testable import TurnkeeperKit

@Suite("Encounter budget")
struct EncounterBudgetTests {
    @Test("XP by level difference, clamped to the table's ends", arguments: [
        (-6, 10), (-4, 10), (-3, 15), (-2, 20), (-1, 30), (0, 40), (1, 60), (2, 80), (3, 120), (4, 160), (6, 160)
    ])
    func experience(difference: Int, experience: Int) {
        let budget = EncounterBudget(partyLevel: 5, partySize: 4)
        #expect(budget.experience(forLevel: 5 + difference) == experience)
        #expect(budget.isOutsideTable(level: 5 + difference) == (abs(difference) > 4))
    }

    @Test("Budgets for parties of 3, 4 and 5", arguments: [
        (3, [30, 45, 60, 90, 120]), (4, [40, 60, 80, 120, 160]), (5, [50, 75, 100, 150, 200])
    ])
    func budgets(size: Int, expected: [Int]) {
        let budget = EncounterBudget(partyLevel: 3, partySize: size)
        #expect(ThreatLevel.allCases.map(budget.budget(for:)) == expected)
    }

    @Test("The table's levels are party level ±4, kept within −1…25", arguments: [
        (3, -1...7), (10, 6...14), (0, -1...4), (24, 20...25), (-1, -1...3), (40, 25...25)
    ])
    func tableLevels(partyLevel: Int, expected: ClosedRange<Int>) {
        #expect(EncounterBudget(partyLevel: partyLevel, partySize: 4).tableLevels == expected)
    }

    @Test("Threat is the lowest tier that covers the XP; above severe is extreme")
    func threat() {
        let budget = EncounterBudget(partyLevel: 3, partySize: 4)
        #expect(budget.threat(forExperience: 40) == .trivial)
        #expect(budget.threat(forExperience: 41) == .low)
        #expect(budget.threat(forExperience: 80) == .moderate)
        #expect(budget.threat(forExperience: 121) == .extreme)
        #expect(!budget.isBeyondExtreme(experience: 160))
        #expect(budget.isBeyondExtreme(experience: 161))
    }
}
