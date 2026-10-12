import Foundation
@testable import CombatPadKit

/// A started fight: a goblin at 17, Valeros at 12 and an ogre at 8, then a wolf at 5 when asked for, plus any
/// events. The IDs come back in turn order.
func fight(events: [EncounterEvent] = [], withWolf: Bool = false) -> (CombatState, [UUID]) {
    var combatants = [Combatant(kind: .creature, name: "Goblin"), Combatant(kind: .playerCharacter, name: "Valeros"),
                      Combatant(kind: .creature, name: "Ogre")]
    if withWolf { combatants.append(Combatant(kind: .creature, name: "Wolf")) }
    var state = CombatState(combatants: combatants.reversed(), events: events)
    for (combatant, initiative) in zip(combatants, [17.0, 12, 8, 5]) {
        state.setInitiative(initiative, for: combatant.id)
    }
    state.beginCombat()
    return (state, combatants.map(\.id))
}
