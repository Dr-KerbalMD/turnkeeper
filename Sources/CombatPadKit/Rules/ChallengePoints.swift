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

public extension Party {
    /// The challenge points of the players present, for a scenario's level range. Nil when the range has no
    /// lowest level to measure from.
    func challengePoints(levelRange: String) -> Int? {
        guard let lowest = ChallengePoints.lowestLevel(in: levelRange), !presentMembers.isEmpty else { return nil }
        return ChallengePoints.total(levels: presentMembers.map { $0.level ?? level }, lowestAllowed: lowest)
    }
}
