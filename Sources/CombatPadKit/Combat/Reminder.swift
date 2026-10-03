import Foundation

/// A card the GM must dismiss when a turn changes, such as "Slowed 1: one fewer action".
public struct Reminder: Sendable, Hashable, Identifiable {
    public var id: UUID
    /// The combatant it is about; nil for round and initiative events.
    public var combatantID: UUID?
    public var title: String
    public var text: String
    public var actions: [ReminderAction]

    public init(combatantID: UUID?, title: String, text: String, actions: [ReminderAction] = []) {
        id = UUID()
        self.combatantID = combatantID
        self.title = title
        self.text = text
        self.actions = actions
    }
}

/// A one-tap response on a reminder card.
public enum ReminderAction: Sendable, Hashable {
    /// Ask for the damage rolled and take it from the combatant's HP.
    case takeDamage(combatantID: UUID)
    /// Remove a condition, such as persistent damage after a successful flat check.
    case removeCondition(conditionID: UUID, combatantID: UUID)
    /// Record a dying recovery check result.
    case recoveryCheck(DegreeOfSuccess, combatantID: UUID)
    /// Undo the automatic change shown on the card, such as frightened going down.
    case undoAutomaticChange(previous: AppliedCondition, combatantID: UUID)
    /// Bring benched combatants from these slots into the fight.
    case bringIn(slotIDs: [UUID])
}

public enum DegreeOfSuccess: String, Sendable, Hashable, CaseIterable {
    case criticalSuccess
    case success
    case failure
    case criticalFailure
}

/// The result of pressing Next: the new state and the reminders to show, in order.
public struct TurnAdvance: Sendable {
    public var state: CombatState
    public var reminders: [Reminder]
}
