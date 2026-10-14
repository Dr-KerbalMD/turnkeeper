import Foundation

/// The board's right half as three stacked panes, the battle card, creature notes and encounter notes, sized
/// as fractions of the height so the split survives rotation and window changes. A notes pane dragged below
/// its minimum collapses to its header.
public struct SplitLayout: Codable, Sendable, Equatable {
    public static let card = 0
    public static let creatureNotes = 1
    public static let encounterNotes = 2
    public static let defaultFractions = [0.6, 0.2, 0.2]
    /// A collapsed pane keeps room for its header.
    public static let headerHeight = 36.0
    public static let minimumHeights = [200.0, 80.0, 80.0]

    /// Each pane's share of the height, adding to 1.
    public private(set) var fractions: [Double]
    /// Notes panes shown as just their header.
    public private(set) var collapsed: Set<Int>

    public init(fractions: [Double] = Self.defaultFractions, collapsed: Set<Int> = []) {
        self.fractions = Self.normalized(fractions.count == 3 ? fractions : Self.defaultFractions)
        self.collapsed = collapsed.subtracting([Self.card])
    }

    /// The panes' heights in `total` points. A hidden pane (`visible` false, such as creature notes on a PC's
    /// turn) gets none, and its share goes to the others in proportion; a collapsed one gets its header.
    public func heights(total: Double, visible: Set<Int> = [0, 1, 2]) -> [Double] {
        let fixed = (0..<3).map { index -> Double? in
            guard visible.contains(index) else { return 0 }
            return collapsed.contains(index) ? Self.headerHeight : nil
        }
        let flexible = (0..<3).filter { fixed[$0] == nil }
        let share = flexible.map { fractions[$0] }.reduce(0, +)
        let room = max(0, total - fixed.compactMap { $0 }.reduce(0, +))
        return (0..<3).map { index in
            fixed[index] ?? (share > 0 ? room * fractions[index] / share : 0)
        }
    }

    public static let allPanes: Set<Int> = [card, creatureNotes, encounterNotes]

    /// Moves the handle between two visible panes, `above` and `below`, by `delta` points. The card keeps its
    /// minimum; a notes pane pushed below its minimum collapses, and one dragged open again expands. Hidden
    /// panes keep their share for when they're shown again.
    public mutating func drag(above: Int, below: Int, by delta: Double, total: Double,
                              visible: Set<Int> = allPanes) {
        guard above < below, visible.isSuperset(of: [above, below]), total > 0 else { return }
        var heights = heights(total: total, visible: visible)
        let pair = heights[above] + heights[below]
        let lowest = above == Self.card ? Self.minimumHeights[Self.card] : Self.headerHeight
        heights[above] = min(max(heights[above] + delta, lowest), pair)
        heights[below] = pair - heights[above]
        updateCollapse(below, heights: &heights, partner: above)
        if above != Self.card { updateCollapse(above, heights: &heights, partner: below) }
        let flexible = visible.filter { !collapsed.contains($0) }
        let share = flexible.map { fractions[$0] }.reduce(0, +)
        let flexibleHeight = flexible.map { heights[$0] }.reduce(0, +)
        guard flexibleHeight > 0 else { return }
        for index in flexible {
            fractions[index] = heights[index] / flexibleHeight * (share > 0 ? share : 1)
        }
        fractions = Self.normalized(fractions)
    }

    /// Back to the default split, all panes open.
    public mutating func reset() {
        self = SplitLayout()
    }

    /// Opens or collapses a notes pane, as a tap on its header does.
    public mutating func toggle(_ pane: Int) {
        guard pane != Self.card else { return }
        if collapsed.contains(pane) { collapsed.remove(pane) } else { collapsed.insert(pane) }
    }

    private mutating func updateCollapse(_ pane: Int, heights: inout [Double], partner: Int) {
        if heights[pane] < Self.minimumHeights[pane] {
            collapsed.insert(pane)
            heights[partner] += heights[pane] - Self.headerHeight
            heights[pane] = Self.headerHeight
        } else {
            collapsed.remove(pane)
        }
    }

    private static func normalized(_ fractions: [Double]) -> [Double] {
        let clamped = fractions.map { max(0.0, $0) }
        let sum = clamped.reduce(0, +)
        return sum > 0 ? clamped.map { $0 / sum } : defaultFractions
    }
}
