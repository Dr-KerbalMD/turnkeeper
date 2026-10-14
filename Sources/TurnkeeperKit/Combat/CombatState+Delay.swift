import Foundation

/// Delay: a delaying strip stays on the ladder, shifted aside, and its turns are skipped until it returns.
public extension CombatState {
    /// The delaying strips between the current turn and the next strip that isn't delaying, top to bottom.
    /// Before the turn passes, the GM chooses which of them act now.
    var delayedStripsAhead: [Combatant] {
        guard let current = currentID, let index = order.firstIndex(of: current) else { return [] }
        return Array(order[(index + 1)...].lazy.compactMap { self[$0] }.prefix { $0.isDelaying })
    }

    /// Starts delaying. Off its own turn the strip moves to just below the next strip that isn't delaying.
    /// On its own turn it stays put until the turn passes, and `TurnAdvancer.next` moves it then and raises
    /// its end-of-turn reminders at once, as the Delay rule says.
    mutating func startDelay(_ id: UUID) {
        guard self[id]?.isDelaying == false, let index = order.firstIndex(of: id) else { return }
        self[id]?.isDelaying = true
        if currentID == id {
            self[id]?.delayedMidTurn = true
        } else if let target = nextActingIndex(after: index) {
            moveBelow(target, [id])
        }
    }

    /// Returns from delaying. The strip keeps its place and acts when the order reaches it.
    mutating func endDelay(_ id: UUID) {
        self[id]?.isDelaying = false
    }

    /// Whether a strip may be dragged to an index in the order: a delaying strip only moves down.
    func canMove(_ id: UUID, toIndex index: Int) -> Bool {
        guard self[id]?.isDelaying == true, let from = order.firstIndex(of: id) else { return true }
        return index >= from
    }

    /// Moves a strip off the ladder to the bench, where it no longer delays.
    mutating func moveToBench(_ id: UUID) {
        order.removeAll { $0 == id }
        self[id]?.place = .bench
        self[id]?.isDelaying = false
        self[id]?.delayedMidTurn = false
    }
}

/// The turn passing over delaying strips, used by `TurnAdvancer`.
extension CombatState {
    /// The first strip below `index` that isn't delaying; nil when every strip below is delaying.
    func nextActingIndex(after index: Int) -> Int? {
        order.indices.first { $0 > index && self[order[$0]]?.isDelaying == false }
    }

    /// Before the turn passes: the delaying strips ahead that the GM chose act now, and the rest, with a
    /// current strip that has just delayed, wait until after the next strip that wasn't delaying. With no such
    /// strip they stay put, to come back when the round ends. Returns who acts next this round, if anyone.
    mutating func passDelayedStrips(actingNow chosen: Set<UUID>) -> UUID? {
        let index = currentID.flatMap { order.firstIndex(of: $0) } ?? -1
        let ahead = delayedStripsAhead.map(\.id)
        let target = nextActingIndex(after: index)
        let incoming = ahead.first(where: chosen.contains) ?? target.map { order[$0] }
        var waiting = ahead.filter { !chosen.contains($0) }
        if let current = currentID, self[current]?.isDelaying == true { waiting.insert(current, at: 0) }
        ahead.filter(chosen.contains).forEach { self[$0]?.isDelaying = false }
        if let target { moveBelow(target, waiting) }
        return incoming
    }

    /// Once the last strip that isn't delaying starts its turn, every delaying strip below it returns, so
    /// they all act before the round ends. A delaying strip whose turn comes up anyway returns too.
    mutating func returnDelayedStripsAtRoundEnd() {
        guard let current = currentID, let index = order.firstIndex(of: current) else { return }
        self[current]?.isDelaying = false
        guard nextActingIndex(after: index) == nil else { return }
        order[(index + 1)...].forEach { self[$0]?.isDelaying = false }
    }

    /// Moves strips, keeping their order, to just below the strip at `index`.
    private mutating func moveBelow(_ index: Int, _ ids: [UUID]) {
        let anchor = order[index]
        let moving = order.filter(ids.contains)
        order.removeAll(where: moving.contains)
        order.insert(contentsOf: moving, at: (order.firstIndex(of: anchor) ?? order.count - 1) + 1)
    }
}
