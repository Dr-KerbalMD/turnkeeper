import Bestiary
import Foundation

/// Applying the one-tap actions on reminder cards.
public extension CombatState {
    /// Applies a reminder action. `amount` is the number entered for `takeDamage`.
    mutating func apply(_ action: ReminderAction, amount: Int = 0) {
        switch action {
        case let .takeDamage(id):
            applyDamage(amount, to: id)
        case let .removeCondition(conditionID, id):
            removeCondition(conditionID, from: id)
        case let .recoveryCheck(degree, id):
            recordRecoveryCheck(degree, for: id)
        case let .undoAutomaticChange(previous, id):
            restore(previous, on: id)
        case .bringIn:
            break  // Needs initiative rolls from the bestiary; the board brings the creatures in.
        }
    }

    /// Whether a dying combatant has died: dying 4, lowered by doomed.
    func isDead(_ id: UUID) -> Bool {
        guard let combatant = self[id], let dying = combatant.condition(ConditionSlug.dying)?.value
        else { return false }
        return dying >= 4 - (combatant.condition("doomed")?.value ?? 0)
    }

    /// A recovery check changes dying by 1 or 2. Reaching dying 0 ends dying and raises wounded by 1.
    private mutating func recordRecoveryCheck(_ degree: DegreeOfSuccess, for id: UUID) {
        guard let dying = self[id]?.condition(ConditionSlug.dying), let value = dying.value else { return }
        let change = [DegreeOfSuccess.criticalSuccess: -2, .success: -1, .failure: 1, .criticalFailure: 2][degree] ?? 0
        let newValue = value + change
        setConditionValue(newValue, conditionID: dying.id, on: id)
        if newValue <= 0 { raiseWounded(on: id) }
    }

    /// Puts a condition back as it was before an automatic change, re-adding it if the change removed it.
    private mutating func restore(_ previous: AppliedCondition, on id: UUID) {
        guard var combatant = self[id] else { return }
        if let index = combatant.conditions.firstIndex(where: { $0.id == previous.id }) {
            combatant.conditions[index] = previous
        } else {
            combatant.conditions.append(previous)
        }
        self[id] = combatant
    }
}
