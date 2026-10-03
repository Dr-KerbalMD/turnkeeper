import Foundation

/// The elite and weak adjustments from the Gamemastery rules, as the pf2e system applies them.
public enum CreatureTemplate: String, Codable, Sendable, CaseIterable {
    case weak
    case normal
    case elite

    /// The creature's level with the template. Elite on level -1 or 0 adds 2; weak on level 1 subtracts 2.
    public func level(base: Int) -> Int {
        let base = max(base, -1)
        switch self {
        case .elite: return base < 1 ? base + 2 : base + 1
        case .weak: return base == 1 ? base - 2 : base - 1
        case .normal: return base
        }
    }

    /// The change to AC, saves, Perception, skills, attacks and DCs.
    public var statisticChange: Int {
        switch self {
        case .elite: return 2
        case .weak: return -2
        case .normal: return 0
        }
    }

    /// The change to Strike damage and other damage. Limited-use abilities change twice as much.
    public func damageChange(isLimited: Bool) -> Int {
        statisticChange * (isLimited ? 2 : 1)
    }

    /// The change to maximum HP, which depends on the creature's level before the template.
    public func hitPointChange(baseLevel: Int) -> Int {
        switch self {
        case .elite: return Self.eliteHitPoints(baseLevel)
        case .weak: return Self.weakHitPoints(baseLevel)
        case .normal: return 0
        }
    }

    private static func eliteHitPoints(_ level: Int) -> Int {
        switch level {
        case 20...: return 30
        case 5...19: return 20
        case 2...4: return 15
        default: return 10
        }
    }

    private static func weakHitPoints(_ level: Int) -> Int {
        switch level {
        case 21...: return -30
        case 6...20: return -20
        case 3...5: return -15
        case 1...2: return -10
        default: return 0
        }
    }
}
