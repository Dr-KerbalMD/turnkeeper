import Foundation

/// Challenge points for organized play: each PC's level, measured from the lowest level allowed at the
/// table, adds to a total that picks the scenario's difficulty.
public enum ChallengePoints {
    /// Points for one PC: the lowest allowed level gives 2, then 3, 4 and 6. Below the range counts as the
    /// lowest; above it counts as the highest.
    public static func points(forLevel level: Int, lowestAllowed: Int) -> Int {
        switch level - lowestAllowed {
        case ...0: return 2
        case 1: return 3
        case 2: return 4
        default: return 6
        }
    }

    public static func total(levels: [Int], lowestAllowed: Int) -> Int {
        levels.reduce(0) { $0 + points(forLevel: $1, lowestAllowed: lowestAllowed) }
    }

    /// The lowest number in a level range such as "3–6", "3-6" or "levels 3 to 6".
    public static func lowestLevel(in levelRange: String) -> Int? {
        levelRange.split { !$0.isNumber }.compactMap { Int($0) }.first
    }

    /// The points a label covers: "16–18 CP" is 16…18, "33+ CP" is 33 and up, "12" is 12 alone.
    /// Labels without numbers, such as "Harder", cover nothing.
    public static func range(of label: String) -> ClosedRange<Int>? {
        let numbers = label.split { !$0.isNumber }.compactMap { Int($0) }
        guard let low = numbers.first else { return nil }
        if label.contains("+") { return low...Int.max }
        return low...max(numbers.dropFirst().first ?? low, low)
    }

    /// The label whose range holds the total, if any.
    public static func label(for total: Int, among labels: [String]) -> String? {
        labels.first { range(of: $0)?.contains(total) == true }
    }
}

/// Starfinder Society's Easier, Base and Harder: each PC at the scenario's lower level (or below) gives 2 points
/// and at its higher level (or above) 3, and the total picks the difficulty. Four lower-level PCs play Easier,
/// four higher-level or six lower-level Base, and six higher-level Harder.
public enum StarfinderDifficulty {
    public static func points(forLevel level: Int, lowestAllowed: Int) -> Int {
        level <= lowestAllowed ? 2 : 3
    }

    public static func total(levels: [Int], lowestAllowed: Int) -> Int {
        levels.reduce(0) { $0 + points(forLevel: $1, lowestAllowed: lowestAllowed) }
    }

    /// Up to 10 points plays Easier, 11–14 Base, and 15 or more Harder.
    public static func label(for total: Int) -> String {
        switch total {
        case ...10: return "Easier"
        case 11...14: return VariantScheme.baseLabel
        default: return "Harder"
        }
    }
}

/// A party's points for a scenario, and the difficulty they pick.
public struct DifficultyPick: Equatable, Sendable {
    public var points: Int
    /// How the points are written: "16 CP", or "12 points" for Starfinder's.
    public var pointsText: String
    /// The scenario's difficulty the points pick; nil when none of its labels covers them.
    public var label: String?
}

public extension Scenario {
    /// How the scenario's difficulties follow from the party's points.
    enum PointScheme: Sendable {
        /// Labels with point ranges, such as "16–18 CP".
        case challengePoints
        /// Easier, Base and Harder.
        case starfinder
    }

    /// The scheme its labels use; nil when they use neither, such as one version only.
    var pointScheme: PointScheme? {
        if variantLabels.contains(where: { ChallengePoints.range(of: $0) != nil }) { return .challengePoints }
        if Set(VariantScheme.easierBaseHarder.labels).isSubset(of: variantLabels) { return .starfinder }
        return nil
    }

    /// The party's points and the difficulty they pick. Nil when the scenario has no point scheme, its level range
    /// has no lowest level, or no one is present.
    func difficulty(for party: Party) -> DifficultyPick? {
        guard let scheme = pointScheme, let lowest = ChallengePoints.lowestLevel(in: levelRange),
              !party.presentLevels.isEmpty else { return nil }
        switch scheme {
        case .challengePoints:
            let points = ChallengePoints.total(levels: party.presentLevels, lowestAllowed: lowest)
            return DifficultyPick(points: points, pointsText: "\(points) CP",
                                  label: ChallengePoints.label(for: points, among: variantLabels))
        case .starfinder:
            let points = StarfinderDifficulty.total(levels: party.presentLevels, lowestAllowed: lowest)
            return DifficultyPick(points: points, pointsText: "\(points) points",
                                  label: StarfinderDifficulty.label(for: points))
        }
    }
}

public extension Party {
    /// The levels of the players present: each one's own, or the party's.
    var presentLevels: [Int] { presentMembers.map { $0.level ?? level } }

    /// The challenge points of the players present, for a scenario's level range. Nil when the range has no
    /// lowest level to measure from.
    func challengePoints(levelRange: String) -> Int? {
        guard let lowest = ChallengePoints.lowestLevel(in: levelRange), !presentMembers.isEmpty else { return nil }
        return ChallengePoints.total(levels: presentLevels, lowestAllowed: lowest)
    }
}
