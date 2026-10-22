import Bestiary
import Foundation

/// HP and condition changes.
public extension CombatState {
    /// Damage comes off temporary HP first.
    mutating func applyDamage(_ amount: Int, to id: UUID) {
        guard var combatant = self[id], amount > 0, combatant.tracksHitPoints else { return }
        let absorbed = min(combatant.temporaryHitPoints, amount)
        combatant.temporaryHitPoints -= absorbed
        combatant.damageTaken += amount - absorbed
        self[id] = combatant
    }

    mutating func heal(_ amount: Int, on id: UUID) {
        guard amount > 0, var combatant = self[id] else { return }
        combatant.damageTaken = max(0, combatant.damageTaken - amount)
        self[id] = combatant
    }

    /// Temporary HP don't stack: the higher amount is kept.
    mutating func grantTemporaryHitPoints(_ amount: Int, to id: UUID) {
        guard var combatant = self[id] else { return }
        combatant.temporaryHitPoints = max(combatant.temporaryHitPoints, amount)
        self[id] = combatant
    }

    /// Adds a condition, or raises the value of one the combatant already has.
    mutating func addCondition(_ condition: AppliedCondition, to id: UUID) {
        guard var combatant = self[id] else { return }
        combatant.conditions.add(condition)
        self[id] = combatant
    }

    /// Sets a valued condition's number; zero or less removes it.
    mutating func setConditionValue(_ value: Int, conditionID: UUID, on id: UUID) {
        guard var combatant = self[id] else { return }
        combatant.conditions.setValue(value, of: conditionID)
        self[id] = combatant
    }

    /// Knocked out at 0 HP: dying 1 plus wounded, unconscious and prone, and its place moves to just before the
    /// current turn. Unconscious and prone are applied rather than left implied by dying, since both outlast it:
    /// a stable creature stays unconscious, and one that wakes stays prone until it Stands.
    mutating func knockOut(_ id: UUID) {
        let wounded = self[id]?.condition(ConditionSlug.wounded)?.value ?? 0
        addCondition(AppliedCondition(slug: ConditionSlug.dying, value: 1 + wounded), to: id)
        addCondition(AppliedCondition(slug: ConditionSlug.unconscious), to: id)
        addCondition(AppliedCondition(slug: ConditionSlug.prone), to: id)
        moveBeforeCurrent(id)
    }

    /// Ends dying: the creature stays unconscious, and wounded goes up by 1.
    mutating func stabilize(_ id: UUID) {
        guard let dying = self[id]?.condition(ConditionSlug.dying) else { return }
        removeCondition(dying.id, from: id)
        addCondition(AppliedCondition(slug: ConditionSlug.unconscious), to: id)
        raiseWounded(on: id)
    }

    mutating func removeCondition(_ conditionID: UUID, from id: UUID) {
        self[id]?.conditions.removeAll { $0.id == conditionID }
    }

    /// Changes a creature's template. Damage taken stays the same, so its current HP moves with the maximum.
    mutating func setTemplate(_ template: CreatureTemplate, for id: UUID) {
        self[id]?.template = template
    }

    mutating func addDuration(_ marker: DurationMarker) {
        durations.append(marker)
    }

    mutating func addEvent(_ event: EncounterEvent) {
        events.append(event)
    }
}

extension CombatState {
    /// Raises wounded by 1, adding wounded 1 when there's none, as when dying ends.
    mutating func raiseWounded(on id: UUID) {
        if let wounded = self[id]?.condition(ConditionSlug.wounded) {
            setConditionValue((wounded.value ?? 0) + 1, conditionID: wounded.id, on: id)
        } else {
            addCondition(AppliedCondition(slug: ConditionSlug.wounded, value: 1), to: id)
        }
    }
}

/// Conditions knocking out applies besides dying.
public extension ConditionSlug {
    static let unconscious = "unconscious"
    static let prone = "prone"
}

/// Condition lists, shared by combatants and by planned encounter slots.
public extension Array where Element == AppliedCondition {
    /// Adds a condition, or raises the value of one already there. Persistent damage and reminders are
    /// separate instances, so they are always added.
    mutating func add(_ condition: AppliedCondition) {
        let isSeparate = [ConditionSlug.persistentDamage, ConditionSlug.customReminder].contains(condition.slug)
        if !isSeparate, let index = firstIndex(where: { $0.slug == condition.slug }) {
            let current = self[index].value ?? 0
            self[index].value = condition.value.map { Swift.max($0, current) }
        } else {
            append(condition)
        }
    }

    /// Sets a valued condition's number; zero or less removes it.
    mutating func setValue(_ value: Int, of conditionID: UUID) {
        guard let index = firstIndex(where: { $0.id == conditionID }) else { return }
        if value <= 0 { remove(at: index) } else { self[index].value = value }
    }
}
