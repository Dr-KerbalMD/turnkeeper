import Foundation

/// Moves the fight to the next turn and gathers the reminders that come due, in rules order:
/// the outgoing combatant's end of turn, the end of the round, the start of the next round, initiative
/// events passed on the way, and the incoming combatant's start of turn.
public enum TurnAdvancer {
    public static func next(_ state: CombatState) -> TurnAdvance {
        var state = state
        guard state.phase == .active, !state.order.isEmpty else { return TurnAdvance(state: state, reminders: []) }
        var reminders: [Reminder] = []
        let outgoing = state.currentID.flatMap { state.order.contains($0) ? $0 : nil }
        if let outgoing {
            reminders += ReminderRules.endOfTurn(&state, combatantID: outgoing)
            reminders += turnEvents(state, slotOf: outgoing, isStart: false)
        }
        let outgoingIndex = outgoing.flatMap { state.order.firstIndex(of: $0) } ?? -1
        let outgoingInitiative = outgoing.flatMap { state[$0]?.initiative } ?? .infinity
        let nextIndex = outgoingIndex + 1
        if nextIndex >= state.order.count {
            reminders += initiativeEvents(state, after: -.infinity, upTo: outgoingInitiative)
            reminders += roundEvents(state, .endOfRound)
            state.round += 1
            reminders += roundEvents(state, .startOfRound)
            state.currentID = state.order[0]
            reminders += initiativeEvents(state, after: initiative(of: state.order[0], in: state), upTo: .infinity)
        } else {
            let incoming = state.order[nextIndex]
            state.currentID = incoming
            reminders += initiativeEvents(state, after: initiative(of: incoming, in: state), upTo: outgoingInitiative)
        }
        if let incoming = state.currentID {
            reminders += ReminderRules.startOfTurn(&state, combatantID: incoming)
            reminders += turnEvents(state, slotOf: incoming, isStart: true)
        }
        return TurnAdvance(state: state, reminders: reminders)
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
