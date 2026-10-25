import TurnkeeperKit
import Foundation

/// A planning edit waiting for the GM to confirm, because it would reset a fight in progress.
struct PendingPlanChange: Identifiable {
    let id = UUID()
    let sessionID: UUID
    let apply: () -> Void
}

/// Starting, resuming, resetting and ending fights.
extension AppModel {
    /// Opens the fight for an encounter at a difficulty: the unfinished one if there is one, otherwise a new
    /// one in setup. Closing the board never loses a fight, because pressing Run again comes back to it.
    func startCombat(encounter: Encounter, variantLabel: String, party: Party?) {
        if let existing = library.unfinishedSession(encounterID: encounter.id, variantLabel: variantLabel) {
            activeSessionID = existing.id
            return
        }
        startNewCombat(encounter: encounter, variantLabel: variantLabel, party: party)
    }

    /// Ends any unfinished fight for the encounter at that difficulty and starts a new one.
    func startOver(encounter: Encounter, variantLabel: String, party: Party?) {
        if let existing = library.unfinishedSession(encounterID: encounter.id, variantLabel: variantLabel) {
            finishSession(existing.id)
        }
        startNewCombat(encounter: encounter, variantLabel: variantLabel, party: party)
    }

    /// The fight for an encounter at a difficulty that has real state to lose, if any.
    func inProgressSession(encounterID: UUID, variantLabel: String) -> CombatSession? {
        library.unfinishedSession(encounterID: encounterID, variantLabel: variantLabel).flatMap {
            $0.isInProgress ? $0 : nil
        }
    }

    func resumeCombat(_ id: UUID) {
        activeSessionID = id
    }

    func closeBoard() {
        activeSessionID = nil
    }

    /// Marks a fight over. It leaves Saved fights, and the next Run builds a fresh one.
    func finishSession(_ id: UUID) {
        guard var session = library.sessions.first(where: { $0.id == id }) else { return }
        session.finishedAt = Date()
        library.save(session)
    }

    /// Takes a finished fight up again.
    func reopenSession(_ id: UUID) {
        guard var session = library.sessions.first(where: { $0.id == id }) else { return }
        session.finishedAt = nil
        library.save(session)
    }

    /// The opening state of a session's encounter as it is planned now, for Reset Combat.
    func freshState(for session: CombatSession) -> CombatState? {
        guard let encounter = encounter(session.encounterID) else { return nil }
        return CombatSetup.state(for: encounter.variant(session.variantLabel), party: party(session.partyID)) {
            entry($0)
        }
    }

    // MARK: Planning edits during a fight

    /// Applies a change to an encounter difficulty's creatures or events, first asking when a fight in
    /// progress would be reset by it.
    func changeVariant(encounterID: UUID, variantLabel: String, apply: @escaping () -> Void) {
        guard let session = inProgressSession(encounterID: encounterID, variantLabel: variantLabel) else {
            apply()
            return
        }
        pendingPlanChange = PendingPlanChange(sessionID: session.id, apply: apply)
    }

    /// The GM confirmed: end the fight the edit would have reset, then apply the edit.
    func confirm(_ pending: PendingPlanChange) {
        pendingPlanChange = nil
        finishSession(pending.sessionID)
        pending.apply()
    }

    private func startNewCombat(encounter: Encounter, variantLabel: String, party: Party?) {
        guard let scenario = scenario(encounter.scenarioID) else { return }
        let party = party.map { settleTableBuddies($0, in: scenario) }
        let state = CombatSetup.state(for: encounter.variant(variantLabel), party: party) { entry($0) }
        var context = SessionContext(campaignID: scenario.campaignID, encounterID: encounter.id,
                                     variantLabel: variantLabel, name: "\(encounter.name) · \(variantLabel)")
        context.partyID = party?.id
        let session = CombatSession(context: context, state: state)
        library.save(session)
        activeSessionID = session.id
    }
}
