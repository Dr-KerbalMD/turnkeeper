import Bestiary
import Foundation
import Testing
@testable import TurnkeeperKit

@Suite("Grouped initiative")
struct InitiativeGroupTests {
    private func combatant(
        _ name: String, key: String, kind: CombatantKind = .creature, side: Side = .enemy,
        place: PadPlace = .ladder, template: CreatureTemplate = .normal
    ) -> Combatant {
        var combatant = Combatant(kind: kind, name: name, side: side, creatureKey: key)
        combatant.place = place
        combatant.template = template
        return combatant
    }

    @Test("A group is one creature on one side, across templates, and only on the ladder")
    func grouping() {
        let normal = combatant("Goblin Warrior 1", key: "goblin")
        let elite = combatant("Goblin Warrior 2", key: "goblin", template: .elite)
        let weak = combatant("Goblin Warrior 3", key: "goblin", template: .weak)
        let reserve = combatant("Goblin Warrior 4", key: "goblin", place: .bench)
        let ally = combatant("Goblin Warrior 5", key: "goblin", side: .ally)
        let pyro = combatant("Goblin Pyro", key: "goblin-pyro")
        let pc = combatant("Kyra", key: "pc.kyra", kind: .playerCharacter, side: .ally)
        let state = CombatState(combatants: [normal, elite, weak, reserve, ally, pyro, pc])

        #expect(state.initiativeGroup(of: normal.id).map(\.name)
            == ["Goblin Warrior 1", "Goblin Warrior 2", "Goblin Warrior 3"])
        // The other side, other creatures, the bench and the players never join.
        #expect(state.initiativeGroup(of: ally.id).map(\.name) == ["Goblin Warrior 5"])
        #expect(state.initiativeGroup(of: pyro.id).map(\.name) == ["Goblin Pyro"])
        #expect(state.initiativeGroup(of: reserve.id).isEmpty)
        #expect(state.initiativeGroup(of: pc.id).isEmpty)
    }

    @Test("Creatures without a key group with nobody")
    func noKey() {
        let first = Combatant(kind: .creature, name: "Unknown 1")
        let second = Combatant(kind: .creature, name: "Unknown 2")
        let state = CombatState(combatants: [first, second])
        #expect(state.initiativeGroup(of: first.id).isEmpty)
    }

    @Test("Set All gives the group one total and sorts the ladder once in setup")
    func setAll() {
        let goblins = (1...3).map { combatant("Goblin Warrior \($0)", key: "goblin") }
        let kyra = combatant("Kyra", key: "pc.kyra", kind: .playerCharacter, side: .ally)
        let wolf = combatant("Wolf", key: "wolf")
        var state = CombatState(combatants: [kyra] + goblins + [wolf])
        state.setInitiative(10, for: kyra.id)
        state.setInitiative(5, for: wolf.id)

        state.setInitiative(18, forGroupOf: goblins[1].id)

        let group = state.combatants.filter { $0.creatureKey == "goblin" }
        #expect(group.allSatisfy { $0.initiative == 18 })
        #expect(state.ladder.map(\.name)
            == ["Goblin Warrior 1", "Goblin Warrior 2", "Goblin Warrior 3", "Kyra", "Wolf"])
    }

    @Test("In a fight, Set All leaves the order and whose turn it is alone")
    func setAllInCombat() {
        let goblins = (1...3).map { combatant("Goblin Warrior \($0)", key: "goblin") }
        let wolf = combatant("Wolf", key: "wolf")
        var state = CombatState(combatants: goblins + [wolf])
        state.setInitiative(20, for: wolf.id)
        state.beginCombat()
        let order = state.order
        let current = state.currentID

        state.setInitiative(1, forGroupOf: goblins[0].id)

        #expect(state.order == order)
        #expect(state.currentID == current)
        #expect(state.combatants.filter { $0.creatureKey == "goblin" }.allSatisfy { $0.initiative == 1 })
    }
}
