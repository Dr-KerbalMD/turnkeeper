import Bestiary
import TurnkeeperKit
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
    /// After "Go Back" from Begin Combat: strips still missing an initiative are outlined.
    var highlightsMissingInitiative = false
    /// The strip the GM tapped to enter its initiative by voice; otherwise entry walks down the ladder.
    var chosenForInitiative: UUID?
    /// The GM chose Keep Going after every enemy fell; cleared once an enemy is up again.
    private var victoryAcknowledged = false
    /// End-of-combat events shown before the fight closes; empty until the GM ends a fight that has some.
    private(set) var endingEvents: [EncounterEvent] = []
    /// A strip swiped to delay, waiting for the GM to confirm.
    var delayToConfirm: Combatant?
    /// Delaying strips the GM is asked about before the turn passes; empty when nobody is asked.
    private(set) var delayedChoice: [Combatant] = []
    /// The fight to pass the turn on from once the GM answers about the delaying strips.
    @ObservationIgnored private var pendingTurn: CombatState?
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
    var isBlocked: Bool { !reminders.isEmpty || !delayedChoice.isEmpty }
    var isFinished: Bool { session?.isFinished ?? false }

    /// Every enemy that has joined the fight is at 0 HP.
    var isVictorious: Bool {
        state.phase == .active && state.allEnemiesDown { maxHitPoints(of: $0) }
    }

    /// Whether to offer ending the fight: all enemies are down and the GM hasn't said to keep going.
    var showsVictory: Bool { isVictorious && !victoryAcknowledged && !isBlocked && !isFinished }

    /// The sheet that ends a fight: Victory!, or the end-of-combat events once the GM ends it.
    var showsEndSheet: Bool { showsVictory || !endingEvents.isEmpty }

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
        endingEvents = []
    }

    /// Ends the fight and closes the board. The next Run starts a new one. When the fight has end-of-combat
    /// events, they show first, and ending again from there closes it.
    func endCombat() {
        if endingEvents.isEmpty, !state.endOfCombatEvents.isEmpty {
            endingEvents = state.endOfCombatEvents
            return
        }
        endingEvents = []
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
        cancelDelayedChoice()
        save(previous)
    }

    func redo() {
        guard let next = redoStack.popLast() else { return }
        undoStack.append(state)
        save(next)
    }

    // MARK: Turns

    /// Next turn, with its reminders queued. Does nothing while reminders are waiting. With delaying strips
    /// just ahead, the GM is asked first which of them act now.
    func next() {
        guard !isBlocked else { return }
        passTurn(from: state)
    }

    /// Delays a strip. On its own turn the turn passes too, as one undo step.
    func startDelay(_ id: UUID) {
        var delayed = state
        delayed.startDelay(id)
        if state.currentID == id, !isBlocked {
            passTurn(from: delayed)
        } else {
            change { $0 = delayed }
        }
    }

    /// The GM's answer about the delaying strips ahead: the chosen act now, top to bottom, and the rest wait.
    func passTurn(actingNow chosen: Set<UUID>) {
        guard let base = pendingTurn else { return }
        pendingTurn = nil
        delayedChoice = []
        let advance = TurnAdvancer.next(base, actingNow: chosen)
        change { $0 = advance.state }
        reminders = advance.reminders
        pinnedID = nil
    }

    /// Closes the question about delaying strips without passing the turn.
    func cancelDelayedChoice() {
        pendingTurn = nil
        delayedChoice = []
    }

    private func passTurn(from base: CombatState) {
        pendingTurn = base
        delayedChoice = base.delayedStripsAhead
        if delayedChoice.isEmpty { passTurn(actingNow: []) }
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
            // They join at the end of the order; the GM rolls and enters their initiative.
            amend { state in ids.forEach { state.bringIn($0) } }
        } else {
            amend { $0.apply(action, amount: amount) }
        }
    }

    // MARK: Initiative

    /// For the optional Roll button: d20 plus the creature's initiative modifier, with the template and
    /// conditions applied. The GM normally rolls.
    func rollInitiative(for combatant: Combatant?) -> Double {
        guard let combatant else { return 10 }
        let modifier = stripCreature(for: combatant).map {
            StatBlockPresenter(creature: $0, template: combatant.template,
                               conditions: combatant.conditions).initiative.value
        } ?? 0
        return CombatSetup.rollInitiative(modifier: modifier, using: &generator)
    }

    /// Brings a benched combatant onto the ladder without an initiative, for the GM to enter one.
    func bringInFromBench(_ id: UUID) {
        change { $0.bringIn(id) }
    }

    /// Initiative modifiers to do the math with: Perception first, then Stealth, then the other skills, with
    /// the template and conditions applied. Empty for PCs.
    func initiativeSkills(for combatant: Combatant) -> [InitiativeSkill] {
        guard let creature = stripCreature(for: combatant) else { return [] }
        let presenter = StatBlockPresenter(creature: creature, template: combatant.template,
                                           conditions: combatant.conditions)
        var skills: [InitiativeSkill] = []
        if creature.kind == .creature {
            skills.append(InitiativeSkill(name: "Perception", modifier: presenter.perception.value,
                                          isInitiative: creature.initiativeStatistic == "perception"))
        }
        if creature.kind == .hazard {
            // A hazard's Stealth is its own statistic, which is also what it rolls for initiative.
            skills.append(InitiativeSkill(name: "Stealth", modifier: presenter.initiative.value,
                                          isInitiative: creature.initiativeStatistic == "stealth"))
        }
        skills += creature.skills.sorted(by: Self.stealthFirst).map { skill in
            InitiativeSkill(name: skill.name, modifier: presenter.skill(skill).value,
                            isInitiative: skill.name.lowercased() == creature.initiativeStatistic)
        }
        return skills
    }

    func beginCombat() {
        change { $0.beginCombat() }
        reminders = []
    }

    // MARK: Lookups

    func creature(for combatant: Combatant) -> Creature? {
        combatant.creatureKey.isEmpty ? nil : model.creature(combatant.creatureKey)
    }

    func entry(for combatant: Combatant) -> BestiaryIndexEntry? {
        model.entry(combatant.creatureKey)
    }

    /// The stat block behind a strip's numbers: AC, HP, initiative modifiers and art. PCs have none, even
    /// with a linked sheet, since players track their own (R6.5); their sheet shows only on the card.
    func stripCreature(for combatant: Combatant) -> Creature? {
        combatant.kind == .playerCharacter ? nil : creature(for: combatant)
    }

    /// Maximum HP with the template and drained applied; 0 when the creature is unknown.
    /// AC with the template and conditions applied, such as 14 for off-guard; nil without a stat block or AC.
    func armorClass(of combatant: Combatant) -> AdjustedValue? {
        guard let creature = stripCreature(for: combatant), creature.defenses.armorClass > 0 else { return nil }
        return StatBlockPresenter(creature: creature, template: combatant.template,
                                  conditions: combatant.conditions).armorClass
    }

    /// The fight as the player screen shows it.
    var playerScreen: PlayerScreenFight {
        state.playerScreen { maxHitPoints(of: $0) }
    }

    func maxHitPoints(of combatant: Combatant) -> Int {
        guard let creature = stripCreature(for: combatant) else { return 0 }
        return StatBlockPresenter(creature: creature, template: combatant.template,
                                  conditions: combatant.conditions).maxHitPoints.value
    }

    private static func stealthFirst(_ first: Skill, _ second: Skill) -> Bool {
        (first.name == "Stealth" ? 0 : 1, first.name) < (second.name == "Stealth" ? 0 : 1, second.name)
    }

    private func save(_ newState: CombatState) {
        guard var session else { return }
        session.state = newState
        model.library.save(session)
        if !isVictorious { victoryAcknowledged = false }
    }
}

/// One modifier in the initiative skill summary.
struct InitiativeSkill: Identifiable, Hashable {
    var name: String
    var modifier: Int
    /// The statistic the stat block says to roll for initiative.
    var isInitiative: Bool

    var id: String { name }
}
