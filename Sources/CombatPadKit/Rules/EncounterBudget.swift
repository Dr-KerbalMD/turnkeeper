import Foundation

/// How dangerous an encounter is for the party.
public enum ThreatLevel: String, Codable, Sendable, CaseIterable, Comparable {
    case trivial
    case low
    case moderate
    case severe
    case extreme

    public static func < (left: ThreatLevel, right: ThreatLevel) -> Bool {
        allCases.firstIndex(of: left) ?? 0 < allCases.firstIndex(of: right) ?? 0
    }

    /// XP budget for a party of four, and the change for each character more or fewer.
    fileprivate var budgetForFour: Int {
        [.trivial: 40, .low: 60, .moderate: 80, .severe: 120, .extreme: 160][self] ?? 0
    }

    fileprivate var characterAdjustment: Int {
        [.trivial: 10, .low: 15, .moderate: 20, .severe: 30, .extreme: 40][self] ?? 0
    }
}

/// Encounter XP by the Core Rulebook and GM Core tables, as the pf2e system's XP macro computes it.
public struct EncounterBudget: Sendable, Equatable {
    public var partyLevel: Int
    public var partySize: Int

    public init(partyLevel: Int, partySize: Int) {
        self.partyLevel = partyLevel
        self.partySize = partySize
    }

    private static let creatureExperience = [-4: 10, -3: 15, -2: 20, -1: 30, 0: 40, 1: 60, 2: 80, 3: 120, 4: 160]

    /// XP for one creature or complex hazard of the given (template-adjusted) level. Like the pf2e
    /// system, levels beyond the table count as its ends; `isOutsideTable` flags them.
    public func experience(forLevel level: Int) -> Int {
        Self.creatureExperience[min(max(level - partyLevel, -4), 4)] ?? 0
    }

    /// Creature levels the XP table covers for this party: party level −4 to +4, kept within the levels
    /// creatures come in (−1 to 25).
    public var tableLevels: ClosedRange<Int> {
        let lower = min(max(Self.lowestLevel, partyLevel - 4), Self.highestLevel)
        return lower...max(min(Self.highestLevel, partyLevel + 4), lower)
    }

    public static let lowestLevel = -1
    public static let highestLevel = 25

    /// Whether a creature is more than four levels from the party, where the XP table stops.
    public func isOutsideTable(level: Int) -> Bool {
        abs(level - partyLevel) > 4
    }

    /// The XP budget for a threat level, adjusted for the party's size.
    public func budget(for threat: ThreatLevel) -> Int {
        threat.budgetForFour + (partySize - 4) * threat.characterAdjustment
    }

    /// The lowest threat level whose budget covers the XP total; anything above severe is extreme.
    public func threat(forExperience experience: Int) -> ThreatLevel {
        ThreatLevel.allCases.dropLast().first { experience <= budget(for: $0) } ?? .extreme
    }

    /// Whether the XP total goes past even the extreme budget.
    public func isBeyondExtreme(experience: Int) -> Bool {
        experience > budget(for: .extreme)
    }
}
