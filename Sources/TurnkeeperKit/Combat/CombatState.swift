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

    private enum CodingKeys: String, CodingKey {
        case phase, round, combatants, order, currentID, events, durations
    }

    /// Sessions saved before delayed strips stayed on the ladder kept them out of the order. They come back
    /// just below the current strip, still delaying, so the next turn offers them a turn.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        phase = try container.decode(CombatPhase.self, forKey: .phase)
        round = try container.decode(Int.self, forKey: .round)
        combatants = try container.decode([Combatant].self, forKey: .combatants)
        order = try container.decode([UUID].self, forKey: .order)
        currentID = try container.decodeIfPresent(UUID.self, forKey: .currentID)
        events = try container.decode([EncounterEvent].self, forKey: .events)
        durations = try container.decode([DurationMarker].self, forKey: .durations)
        let missing = combatants.filter { $0.place == .ladder && !order.contains($0.id) }.map(\.id)
        let below = currentID.flatMap { order.firstIndex(of: $0) }.map { $0 + 1 } ?? order.count
        order.insert(contentsOf: missing, at: below)
    }

    public subscript(id: UUID) -> Combatant? {
        get { combatants.first { $0.id == id } }
        set {
            guard let index = combatants.firstIndex(where: { $0.id == id }) else { return }
            if let newValue { combatants[index] = newValue } else { combatants.remove(at: index) }
        }
    }

    /// Enabled events to read out when the GM ends the fight.
    public var endOfCombatEvents: [EncounterEvent] { events.filter { $0.isEnabled && $0.isAtEndOfCombat } }

    /// The combatants on the ladder, in turn order.
    public var ladder: [Combatant] { order.compactMap { self[$0] } }
    public var bench: [Combatant] { combatants.filter { $0.place == .bench } }
    /// Strips on the ladder whose turns are skipped until they return.
    public var delaying: [Combatant] { ladder.filter(\.isDelaying) }
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

    /// Whose initiative voice entry sets next: the strip the GM chose, else the first one still without a
    /// number, so entry walks down the ladder by itself. Nil when everyone has one.
    public func initiativeTarget(chosen: UUID?) -> UUID? {
        if let chosen, ladder.contains(where: { $0.id == chosen }) { return chosen }
        return combatantsWithoutInitiative.first?.id
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

    /// The combatants that can share `id`'s initiative: the same creature on the same side, on the ladder.
    /// Templates and conditions may differ, so the group is by creature rather than by stat block. Players
    /// have a key of their own, and the bench joins the fight with its own number, so neither is included.
    public func initiativeGroup(of id: UUID) -> [Combatant] {
        guard let reference = self[id], reference.place == .ladder,
              reference.kind != .playerCharacter, !reference.creatureKey.isEmpty else { return [] }
        return ladder.filter {
            $0.kind != .playerCharacter && $0.side == reference.side
                && $0.creatureKey == reference.creatureKey
        }
    }

    /// Sets one rolled total for every creature of the same type, as when the GM groups them. Setup sorts
    /// once; in a fight the board keeps whose turn it is.
    public mutating func setInitiative(_ value: Double, forGroupOf id: UUID) {
        for member in initiativeGroup(of: id) {
            self[member.id]?.initiative = value
        }
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

    /// Moves a strip to a new place in the order, as when the GM drags it. A delaying strip only moves down.
    public mutating func move(_ id: UUID, toIndex index: Int) {
        guard let from = order.firstIndex(of: id), canMove(id, toIndex: index) else { return }
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
