import Bestiary
import Foundation

/// The reminders a combatant's conditions, notes and duration arrows raise at the start and end of its
/// turn. Changes the rules make automatically, such as frightened going down, are applied here and can be
/// undone from the reminder card.
public enum ReminderRules {
    public static func startOfTurn(_ state: inout CombatState, combatantID id: UUID) -> [Reminder] {
        guard let combatant = state[id] else { return [] }
        var reminders: [Reminder] = []
        for condition in combatant.conditions {
            reminders += startReminders(for: condition, of: combatant, state: &state)
        }
        reminders += noteReminders(combatant, at: .startOfTurn)
        reminders += countDurations(&state, anchor: id, at: .startOfTurn)
        return reminders
    }

    public static func endOfTurn(_ state: inout CombatState, combatantID id: UUID) -> [Reminder] {
        guard let combatant = state[id] else { return [] }
        var reminders: [Reminder] = []
        for condition in combatant.conditions {
            reminders += endReminders(for: condition, of: combatant, state: &state)
        }
        reminders += noteReminders(combatant, at: .endOfTurn)
        reminders += countDurations(&state, anchor: id, at: .endOfTurn)
        return reminders
    }

    private static func startReminders(
        for condition: AppliedCondition, of combatant: Combatant, state: inout CombatState
    ) -> [Reminder] {
        let value = condition.value ?? 0
        switch condition.slug {
        case ConditionSlug.dying:
            let actions = DegreeOfSuccess.allCases.map { ReminderAction.recoveryCheck($0, combatantID: combatant.id) }
            return [Reminder(combatantID: combatant.id, title: "Dying \(value)",
                             text: "Recovery check: DC \(10 + value) flat check.", actions: actions)]
        case ConditionSlug.slowed where combatant.condition(ConditionSlug.stunned) == nil:
            return [Reminder(combatantID: combatant.id, title: "Slowed \(value)",
                             text: "\(actionCount(value)) fewer this turn.")]
        case ConditionSlug.stunned:
            return [stunned(condition, of: combatant, state: &state)]
        case ConditionSlug.quickened:
            return [Reminder(combatantID: combatant.id, title: "Quickened",
                             text: "1 extra action this turn, used only as the effect allows.")]
        default:
            return []
        }
    }

    /// Stunned with a value loses that many actions, at most 3, and goes down by the actions lost.
    private static func stunned(
        _ condition: AppliedCondition, of combatant: Combatant, state: inout CombatState
    ) -> Reminder {
        guard let value = condition.value else {
            return Reminder(combatantID: combatant.id, title: "Stunned", text: "Can't act this turn.")
        }
        let lost = min(value, 3)
        state.setConditionValue(value - lost, conditionID: condition.id, on: combatant.id)
        let after = value - lost > 0 ? "stunned \(value - lost) remains" : "stunned ends"
        return Reminder(combatantID: combatant.id, title: "Stunned \(value)",
                        text: "Loses \(actionCount(lost)) this turn; \(after).",
                        actions: [.undoAutomaticChange(previous: condition, combatantID: combatant.id)])
    }

    private static func endReminders(
        for condition: AppliedCondition, of combatant: Combatant, state: inout CombatState
    ) -> [Reminder] {
        switch condition.slug {
        case ConditionSlug.persistentDamage:
            return [persistentDamage(condition, of: combatant)]
        case ConditionSlug.frightened:
            let value = condition.value ?? 1
            state.setConditionValue(value - 1, conditionID: condition.id, on: combatant.id)
            let after = value > 1 ? "frightened \(value - 1)" : "no longer frightened"
            return [Reminder(combatantID: combatant.id, title: "Frightened \(value)",
                             text: "Goes down by 1 at the end of the turn: now \(after).",
                             actions: [.undoAutomaticChange(previous: condition, combatantID: combatant.id)])]
        default:
            return []
        }
    }

    private static func persistentDamage(_ condition: AppliedCondition, of combatant: Combatant) -> Reminder {
        let damage = condition.persistentDamage ?? DamagePart(formula: "?", type: "")
        let description = [damage.formula, damage.type].filter { !$0.isEmpty }.joined(separator: " ")
        var actions: [ReminderAction] = combatant.tracksHitPoints ? [.takeDamage(combatantID: combatant.id)] : []
        actions.append(.removeCondition(conditionID: condition.id, combatantID: combatant.id))
        return Reminder(combatantID: combatant.id, title: "Persistent \(description)",
                        text: "Take \(description) damage, then a DC 15 flat check to end it (DC 10 with help).",
                        actions: actions)
    }

    private static func noteReminders(_ combatant: Combatant, at moment: TurnMoment) -> [Reminder] {
        combatant.conditions.filter { $0.slug == ConditionSlug.customReminder && $0.noteMoment == moment }
            .map { Reminder(combatantID: combatant.id, title: combatant.name, text: $0.note) }
    }

    /// Counts down duration arrows anchored at this point and reports the ones that run out.
    private static func countDurations(_ state: inout CombatState, anchor: UUID, at moment: TurnMoment) -> [Reminder] {
        var expired: [Reminder] = []
        for index in state.durations.indices.reversed()
        where state.durations[index].anchorCombatantID == anchor && state.durations[index].moment == moment {
            state.durations[index].roundsRemaining -= 1
            if state.durations[index].roundsRemaining <= 0 {
                expired.append(Reminder(combatantID: anchor, title: "\(state.durations[index].label) ends",
                                        text: "The duration has run out."))
                state.durations.remove(at: index)
            }
        }
        return expired.reversed()
    }

    private static func actionCount(_ count: Int) -> String {
        count == 1 ? "1 action" : "\(count) actions"
    }
}
