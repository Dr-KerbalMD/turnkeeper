import CombatPadKit
import Foundation
import Observation

/// Runs a fight on the board: changes go through here so they're saved, can be undone, and raise reminders.
@Observable
@MainActor
final class BoardController {
    let sessionID: UUID
    private let model: AppModel
    /// Reminders waiting to be dismissed, first one showing. Next is blocked until they're all gone.
    private(set) var reminders: [Reminder] = []
    /// The combatant whose card is pinned; nil follows the current turn.
    var pinnedID: UUID?
    /// The GM chose Keep Going after every enemy fell; cleared once an enemy is up again.
    private var victoryAcknowledged = false
    private var undoStack: [CombatState] = []
    private var redoStack: [CombatState] = []
    @ObservationIgnored private var generator = SystemRandomNumberGenerator()

    init(sessionID: UUID, model: AppModel) {
        self.sessionID = sessionID
        self.model = model
    }

    var session: CombatSession? { model.library.sessions.first { $0.id == sessionID } }
    var state: CombatState { session?.state ?? CombatState() }
    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }
    var isBlocked: Bool { !reminders.isEmpty }
    var isFinished: Bool { session?.isFinished ?? false }

    /// Every enemy that has joined the fight is at 0 HP.
    var isVictorious: Bool {
        state.phase == .active && state.allEnemiesDown { maxHitPoints(of: $0) }
    }

    /// Whether to offer ending the fight: all enemies are down and the GM hasn't said to keep going.
    var showsVictory: Bool { isVictorious && !victoryAcknowledged && !isBlocked && !isFinished }

    /// The combatant whose card shows: the pinned one, or whoever's turn it is.
    var cardCombatant: Combatant? {
        (pinnedID ?? state.currentID).flatMap { state[$0] }
    }

    // MARK: Changes

    /// Applies a change, saving it and keeping the previous state for undo.
    func change(_ edit: (inout CombatState) -> Void) {
        var newState = state
        edit(&newState)
        guard newState != state else { return }
        undoStack.append(state)
        if undoStack.count > 100 { undoStack.removeFirst() }
        redoStack.removeAll()
        save(newState)
    }

    /// A change that belongs to the last undo step, such as acting on a reminder from that turn.
    func amend(_ edit: (inout CombatState) -> Void) {
        var newState = state
        edit(&newState)
        save(newState)
    }

    // MARK: The whole fight

    /// Puts the fight back to setup from the encounter's current plan. It can be undone.
    func reset() {
        guard let session, let fresh = model.freshState(for: session) else { return }
        reminders.removeAll()
        pinnedID = nil
        change { $0 = fresh }
    }

    func keepGoing() {
        victoryAcknowledged = true
    }

    /// Ends the fight and closes the board. The next Run starts a new one.
    func endCombat() {
        model.finishSession(sessionID)
        model.closeBoard()
    }

    func reopen() {
        model.reopenSession(sessionID)
    }

    func undo() {
        guard let previous = undoStack.popLast() else { return }
        redoStack.append(state)
        reminders.removeAll()
        save(previous)
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(state)
        save(next)
    }

    // MARK: Turns

    /// Next turn, with its reminders queued. Does nothing while reminders are waiting.
    func next() {
        guard !isBlocked else { return }
        let advance = TurnAdvancer.next(state)
        change { $0 = advance.state }
        reminders = advance.reminders
        pinnedID = nil
    }

    /// Dismisses the front reminder, applying an action from it first if one was chosen.
    func dismissReminder(applying action: ReminderAction? = nil, amount: Int = 0) {
        guard !reminders.isEmpty else { return }
        if let action { perform(action, amount: amount) }
        reminders.removeFirst()
    }

    private func perform(_ action: ReminderAction, amount: Int) {
        if case let .bringIn(slotIDs) = action {
            let ids = state.bench.filter { $0.slotID.map(slotIDs.contains) ?? false }.map(\.id)
            amend { state in ids.forEach { state.bringIn($0, initiative: rollInitiative(for: state[$0])) } }
        } else {
            amend { $0.apply(action, amount: amount) }
        }
    }

    // MARK: Initiative

    /// Rolls initiative for every creature and hazard that has none yet. PCs are left to the players.
    func rollCreatureInitiative() {
        change { state in
            for combatant in state.combatants where combatant.kind != .playerCharacter && combatant.initiative == nil {
                state.setInitiative(rollInitiative(for: combatant), for: combatant.id)
            }
        }
    }

    func rollInitiative(for combatant: Combatant?) -> Double {
        guard let combatant else { return 10 }
        let modifier = creature(for: combatant).map {
            StatBlockPresenter(creature: $0, template: combatant.template).initiative.value
        } ?? 0
        return CombatSetup.rollInitiative(modifier: modifier, using: &generator)
    }

    func bringInFromBench(_ id: UUID, initiative: Double? = nil) {
        change { state in state.bringIn(id, initiative: initiative ?? rollInitiative(for: state[id])) }
    }

    func beginCombat() {
        change { $0.beginCombat() }
        reminders = []
    }

    // MARK: Lookups

    func creature(for combatant: Combatant) -> Creature? {
        combatant.creatureKey.isEmpty ? nil : model.bestiary.creature(combatant.creatureKey)
    }

    func entry(for combatant: Combatant) -> BestiaryIndexEntry? {
        model.bestiary.entry(combatant.creatureKey)
    }

    /// Maximum HP with the template and drained applied; custom NPCs use the HP they were given.
    func maxHitPoints(of combatant: Combatant) -> Int {
        if let creature = creature(for: combatant) {
            return StatBlockPresenter(creature: creature, template: combatant.template,
                                      conditions: combatant.conditions).maxHitPoints.value
        }
        return combatant.customMaxHitPoints
    }

    private func save(_ newState: CombatState) {
        guard var session else { return }
        session.state = newState
        model.library.save(session)
        if !isVictorious { victoryAcknowledged = false }
    }
}
