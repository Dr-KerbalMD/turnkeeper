import Foundation

/// The level a Table Buddy (an iconic pregen) plays at.
///
/// Pathfinder follows the Pathfinder Society Guide's "Adding Pregens" table (under "Calculating Challenge
/// Points"): the scenario's Base Level, how many real PCs there are and their challenge points pick level 1, 3
/// or 5, and no pregens join adventures for level 7 and up. Starfinder adventures come in two-level bands that
/// start on a pregen's level, so the pregen matches the band's lower level.
public enum PregenLevel {
    /// The Guide's level for a Pathfinder pregen; nil when the Guide allows none (Base Level 7 and up). The table
    /// covers two or three real PCs; a smaller or larger table uses the nearest row.
    public static func pathfinder(baseLevel: Int, realLevels: [Int]) -> Int? {
        guard baseLevel < 7 else { return nil }
        guard baseLevel < 5 else { return 5 }
        let lower = baseLevel < 3 ? 1 : 3
        let points = ChallengePoints.total(levels: realLevels, lowestAllowed: baseLevel)
        let threshold = realLevels.count <= 2 ? 8 : 12
        return points < threshold ? lower : lower + 2
    }

    /// The pregen's own level for a wanted level: the highest it has at or below, else its lowest.
    public static func available(_ wanted: Int, among levels: [Int]) -> Int? {
        levels.filter { $0 <= wanted }.max() ?? levels.min()
    }
}
