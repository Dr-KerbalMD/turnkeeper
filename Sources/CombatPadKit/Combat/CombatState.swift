import Foundation

public enum CombatPhase: String, Codable, Sendable {
    /// Rolling for initiative, before round 1. Voice entry works only here.
    case setup
    case active
}

/// Everything about a fight in progress. A value type, so every change can be undone by keeping the
/// previous value.
public struct CombatState: Codable, Sendable, Hashable {
    public var phase: CombatPhase
    public var round: Int
    public var combatants: [Combatant]
    /// Initiative order of the combatants on the ladder, first to act first.
    public var order: [UUID]
    public var currentID: UUID?
    public var events: [EncounterEvent]
    public var durations: [DurationMarker]

    public init(combatants: [Combatant] = [], events: [EncounterEvent] = []) {
        phase = .setup
        round = 0
        self.combatants = combatants
        order = combatants.filter { $0.place == .ladder }.map(\.id)
        currentID = nil
        self.events = events
        durations = []
    }

    public subscript(id: UUID) -> Combatant? {
        get { combatants.first { $0.id == id } }
        set {
            guard let index = combatants.firstIndex(where: { $0.id == id }) else { return }
            if let newValue { combatants[index] = newValue } else { combatants.remove(at: index) }
        }
    }

    /// The combatants on the ladder, in turn order.
    public var ladder: [Combatant] { order.compactMap { self[$0] } }
    public var bench: [Combatant] { combatants.filter { $0.place == .bench } }
    public var delaying: [Combatant] { combatants.filter { $0.place == .delaying } }
    public var current: Combatant? { currentID.flatMap { self[$0] } }

    // MARK: Progress

    /// Combat has begun, or at least one initiative has been entered.
    public var hasStarted: Bool {
        phase == .active || combatants.contains { $0.initiative != nil }
    }

    /// Combatants on the ladder still without an initiative, in ladder order. The bench doesn't count.
    public var combatantsWithoutInitiative: [Combatant] {
        ladder.filter { $0.initiative == nil }
    }

    /// Whether every enemy that has joined the fight is at 0 HP. Benched enemies haven't joined, hazards are
    /// disabled rather than killed, and allies and PCs don't count. False when there are no such enemies.
    public func allEnemiesDown(maxHitPoints: (Combatant) -> Int) -> Bool {
        let enemies = combatants.filter { combatant in
            combatant.side == .enemy && combatant.place != .bench
                && combatant.kind != .hazard && combatant.kind != .playerCharacter
        }
        return !enemies.isEmpty && enemies.allSatisfy { maxHitPoints($0) - $0.damageTaken <= 0 }
    }

    // MARK: Setup

    /// Sets a rolled initiative. During setup the ladder re-sorts at once.
    public mutating func setInitiative(_ value: Double, for id: UUID) {
        self[id]?.initiative = value
        if phase == .setup { sortByInitiative() }
    }

    /// Highest initiative first. On a tie enemies act before the party, as the rules say; otherwise
    /// the existing order is kept.
    public mutating func sortByInitiative() {
        let position = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
        order = ladder.sorted { first, second in
            let (left, right) = (first.initiative ?? -100, second.initiative ?? -100)
            if left != right { return left > right }
            if first.side != second.side { return first.side == .enemy }
            return position[first.id, default: 0] < position[second.id, default: 0]
        }.map(\.id)
    }

    /// Ends setup and starts round 1 with the first combatant on the ladder.
    public mutating func beginCombat() {
        sortByInitiative()
        phase = .active
        round = 1
        currentID = order.first
    }

    // MARK: Ladder changes

    /// Moves a strip to a new place in the order, as when the GM drags it.
    public mutating func move(_ id: UUID, toIndex index: Int) {
        guard let from = order.firstIndex(of: id) else { return }
        order.remove(at: from)
        order.insert(id, at: min(max(index, 0), order.count))
    }

    /// Brings a benched combatant into the fight: at its initiative, after others with the same count, or at
    /// the end of the order until the GM enters one.
    public mutating func bringIn(_ id: UUID, initiative: Double? = nil) {
        guard self[id]?.place == .bench else { return }
        self[id]?.place = .ladder
        self[id]?.initiative = initiative
        let index = initiative.flatMap { value in ladder.firstIndex { ($0.initiative ?? -100) < value } }
        order.insert(id, at: index ?? order.count)
    }

    /// Takes a combatant out of the order to Delay. Delaying on its own turn passes the turn on.
    public mutating func startDelay(_ id: UUID) {
        guard let index = order.firstIndex(of: id) else { return }
        if currentID == id { currentID = order.count > 1 ? order[(index + 1) % order.count] : nil }
        order.remove(at: index)
        self[id]?.place = .delaying
    }

    /// A delaying combatant returns: it acts now, and its place in the order becomes this point.
    public mutating func endDelay(_ id: UUID) {
        guard self[id]?.place == .delaying else { return }
        self[id]?.place = .ladder
        let index = currentID.flatMap { order.firstIndex(of: $0) } ?? order.count
        order.insert(id, at: index)
        currentID = id
    }

    /// When a combatant is knocked out, its place moves to just before the turn it happened on.
    public mutating func moveBeforeCurrent(_ id: UUID) {
        guard id != currentID, let current = currentID, order.contains(id) else { return }
        order.removeAll { $0 == id }
        order.insert(id, at: order.firstIndex(of: current) ?? 0)
    }

    public mutating func remove(_ id: UUID) {
        if currentID == id, let index = order.firstIndex(of: id), order.count > 1 {
            currentID = order[(index + 1) % order.count]
        }
        order.removeAll { $0 == id }
        durations.removeAll { $0.anchorCombatantID == id }
        self[id] = nil
    }
}
