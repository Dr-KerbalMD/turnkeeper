import Bestiary
import Foundation
import Testing
@testable import CombatPadKit

@Suite("The player screen's initiative order")
struct PlayerScreenTests {
    /// Every creature has 40 HP; PCs have none on the pad.
    private func lines(_ state: CombatState) -> [PlayerScreenLine] {
        state.playerScreen { $0.tracksHitPoints ? 40 : 0 }.lines
    }

    @Test("The ladder in order, the current strip active, delaying strips marked")
    func order() {
        var (state, ids) = fight()
        state.startDelay(ids[2])
        let result = lines(state)
        #expect(result.map(\.id) == ids)
        #expect(result.map(\.isActive) == [true, false, false])
        #expect(result.map(\.isDelaying) == [false, false, true])
        #expect(result.map(\.magnet) == [.red, .blue, .red])
    }

    @Test("Benched combatants are left out")
    func benchHidden() {
        var (state, ids) = fight()
        var wolf = Combatant(kind: .creature, name: "Wolf")
        wolf.place = .bench
        state.combatants.append(wolf)
        #expect(lines(state).map(\.id) == ids)
    }

    @Test("Enemies show a health estimate; PCs and allies show none")
    func healthOnlyForEnemies() {
        var (state, ids) = fight()
        state.applyDamage(25, to: ids[0])
        state[ids[2]]?.side = .ally
        let health = lines(state).map(\.health)
        #expect(health == [.bloodied, nil, nil])
    }

    @Test("Damage moves an enemy through the bands", arguments: [
        (0, HealthEstimate.unharmed), (1, .healthy), (9, .healthy), (10, .injured), (19, .injured),
        (20, .bloodied), (29, .bloodied), (30, .nearDeath), (39, .nearDeath), (40, .down), (55, .down)
    ])
    func bands(damage: Int, expected: HealthEstimate) {
        var (state, ids) = fight()
        state.applyDamage(damage, to: ids[0])
        #expect(lines(state).first?.health == expected)
    }

    @Test("A dying enemy is down whatever its HP")
    func dyingIsDown() {
        var (state, ids) = fight()
        state.knockOut(ids[0])
        #expect(lines(state).first { $0.id == ids[0] }?.health == .down)
    }

    @Test("An enemy without a known maximum shows no estimate")
    func unknownMaximum() {
        let (state, _) = fight()
        #expect(state.playerScreen { _ in 0 }.lines.allSatisfy { $0.health == nil })
    }

    @Test("Before combat begins, nobody is active and there's no art")
    func setupHasNoActiveStrip() {
        let state = CombatState(combatants: [Combatant(kind: .creature, name: "Goblin", creatureKey: "goblin")])
        #expect(lines(state).map(\.isActive) == [false])
        #expect(state.playerScreen { _ in 0 }.activeKey.isEmpty)
    }

    @Test("The art is the acting combatant's")
    func activeArt() {
        var (state, ids) = fight()
        state[ids[0]]?.creatureKey = "goblin-warrior"
        #expect(state.playerScreen { _ in 0 }.activeKey == "goblin-warrior")
    }
}
