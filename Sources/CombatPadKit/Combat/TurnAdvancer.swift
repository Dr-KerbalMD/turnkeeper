import Foundation

/// Moves the fight to the next turn and gathers the reminders that come due, in rules order:
/// the outgoing combatant's end of turn, the end of the round, the start of the next round, initiative
/// events passed on the way, and the incoming combatant's start of turn.
public enum TurnAdvancer {
    /// Delaying strips are skipped. Those between this turn and the next strip that isn't delaying act now
    /// if they're in `actingNow`, and otherwise wait below that strip. A strip that delays on its own turn
    /// has its end of turn now, as the Delay rule says, and none when it returns to finish the turn.
    public static func next(_ state: CombatState, actingNow: Set<UUID> = []) -> TurnAdvance {
        var state = state
        guard state.phase == .active, !state.order.isEmpty else { return TurnAdvance(state: state, reminders: []) }
        var reminders: [Reminder] = []
        let outgoing = state.currentID.flatMap { state.order.contains($0) ? $0 : nil }
        if let outgoing { reminders += endOfTurn(&state, outgoing) }
        let outgoingInitiative = outgoing.flatMap { state[$0]?.initiative } ?? .infinity
        if let incoming = state.passDelayedStrips(actingNow: actingNow) {
            state.currentID = incoming
            reminders += initiativeEvents(state, after: initiative(of: incoming, in: state), upTo: outgoingInitiative)
        } else {
            reminders += initiativeEvents(state, after: -.infinity, upTo: outgoingInitiative)
            reminders += roundEvents(state, .endOfRound)
            state.round += 1
            reminders += roundEvents(state, .startOfRound)
            let first = state.order[state.nextActingIndex(after: -1) ?? 0]
            state.currentID = first
            reminders += initiativeEvents(state, after: initiative(of: first, in: state), upTo: .infinity)
        }
        state.returnDelayedStripsAtRoundEnd()
        if let incoming = state.currentID, state[incoming]?.delayedMidTurn == false {
            reminders += ReminderRules.startOfTurn(&state, combatantID: incoming)
            reminders += turnEvents(state, slotOf: incoming, isStart: true)
        }
        return TurnAdvance(state: state, reminders: reminders)
    }

    /// The outgoing strip's end of turn. One returning from a delay finishes its turn quietly: its end of turn
    /// came when it delayed.
    private static func endOfTurn(_ state: inout CombatState, _ id: UUID) -> [Reminder] {
        guard let combatant = state[id] else { return [] }
        if combatant.delayedMidTurn && !combatant.isDelaying {
            state[id]?.delayedMidTurn = false
            return []
        }
        return ReminderRules.endOfTurn(&state, combatantID: id) + turnEvents(state, slotOf: id, isStart: false)
    }

    private static func initiative(of id: UUID, in state: CombatState) -> Double {
        state[id]?.initiative ?? -.infinity
    }

    /// Events at initiative counts the order just passed: above `lower` and at or below `upper`, so an
    /// event at 15 fires after a combatant at 15 acts. Highest count first.
    private static func initiativeEvents(_ state: CombatState, after lower: Double, upTo upper: Double) -> [Reminder] {
        state.events.filter { event in
            guard let count = event.initiativeCount, event.isEnabled else { return false }
            return Double(count) > lower && Double(count) <= upper && event.occurrence.includes(round: state.round)
        }
        .sorted { ($0.initiativeCount ?? 0) > ($1.initiativeCount ?? 0) }
        .map(reminder)
    }

    private static func roundEvents(_ state: CombatState, _ trigger: EventTrigger) -> [Reminder] {
        state.events.filter { $0.isEnabled && $0.trigger == trigger && $0.occurrence.includes(round: state.round) }
            .map(reminder)
    }

    private static func turnEvents(_ state: CombatState, slotOf id: UUID, isStart: Bool) -> [Reminder] {
        guard let slot = state[id]?.slotID else { return [] }
        let trigger: EventTrigger = isStart ? .turnStart(slotID: slot) : .turnEnd(slotID: slot)
        return state.events
            .filter { $0.isEnabled && $0.trigger == trigger && $0.occurrence.includes(round: state.round) }
            .map(reminder)
    }

    private static func reminder(for event: EncounterEvent) -> Reminder {
        let actions: [ReminderAction] = event.bringsInSlotIDs.isEmpty ? [] : [.bringIn(slotIDs: event.bringsInSlotIDs)]
        return Reminder(combatantID: nil, title: event.label, text: event.text, actions: actions)
    }
}
