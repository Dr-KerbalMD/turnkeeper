import Bestiary
import Foundation
import Testing
@testable import CombatPadKit

@Suite("Delaying on the ladder")
struct DelayTests {
    @Test("Delaying on its own turn passes the turn and waits below the next strip")
    func delayOnOwnTurn() {
        var (state, ids) = fight()
        state.addCondition(AppliedCondition(slug: "frightened", value: 2), to: ids[0])
        state.startDelay(ids[0])
        let advance = TurnAdvancer.next(state)
        #expect(advance.state.currentID == ids[1])
        #expect(advance.state.order == [ids[1], ids[0], ids[2]])
        #expect(advance.state.delaying.map(\.id) == [ids[0]])
        #expect(advance.state[ids[0]]?.condition("frightened")?.value == 1, "Its end of turn comes at once")
        #expect(advance.reminders.map(\.title) == ["Frightened 2"])
    }

    @Test("Returning from a delay on its own turn finishes that turn without its turn reminders again")
    func returnFinishesTurn() {
        var (state, ids) = fight()
        let bleed = DamagePart(formula: "1d6", type: "bleed", isPersistent: true)
        state.addCondition(.persistent(bleed), to: ids[0])
        state.startDelay(ids[0])
        let delayed = TurnAdvancer.next(state)
        #expect(delayed.reminders.map(\.title) == ["Persistent 1d6 bleed"])
        let returned = TurnAdvancer.next(delayed.state, actingNow: [ids[0]])
        #expect(returned.state.currentID == ids[0])
        #expect(returned.reminders.isEmpty)
        let finished = TurnAdvancer.next(returned.state)
        #expect(!finished.reminders.contains { $0.title == "Persistent 1d6 bleed" })
        #expect(finished.state[ids[0]]?.delayedMidTurn == false)
        let nextRound = TurnAdvancer.next(finished.state)
        #expect(nextRound.state.round == 2)
        let goblinsTurn = TurnAdvancer.next(nextRound.state)
        #expect(goblinsTurn.state.currentID == ids[0])
        let laterEnd = TurnAdvancer.next(goblinsTurn.state).reminders.map(\.title)
        #expect(laterEnd == ["Persistent 1d6 bleed"], "A later turn ends as usual")
    }

    @Test("Delaying off its own turn moves the strip below the next one")
    func delayOffTurn() {
        var (state, ids) = fight()
        state.startDelay(ids[1])
        #expect(state.order == [ids[0], ids[2], ids[1]])
        #expect(state.currentID == ids[0])
    }

    @Test("A delayed strip ahead that acts now takes the next turn")
    func oneDelayedActsNow() {
        let (state, ids) = delayedGoblin()
        #expect(state.delayedStripsAhead.map(\.id) == [ids[0]])
        let advance = TurnAdvancer.next(state, actingNow: [ids[0]])
        #expect(advance.state.currentID == ids[0])
        #expect(advance.state.order == [ids[1], ids[0], ids[2]])
        #expect(advance.state.delaying.isEmpty)
    }

    @Test("A delayed strip ahead that keeps waiting moves below the next strip")
    func oneDelayedWaits() {
        let (state, ids) = delayedGoblin()
        let advance = TurnAdvancer.next(state)
        #expect(advance.state.currentID == ids[2])
        #expect(advance.state.order == [ids[1], ids[2], ids[0]])
    }

    @Test("Of several delayed strips ahead, the chosen act now and the rest wait below the next strip")
    func severalDelayed() {
        var (state, ids) = fight(withWolf: true)
        state[ids[1]]?.isDelaying = true
        state[ids[2]]?.isDelaying = true
        #expect(state.delayedStripsAhead.map(\.id) == [ids[1], ids[2]])
        let advance = TurnAdvancer.next(state, actingNow: [ids[2]])
        #expect(advance.state.currentID == ids[2])
        #expect(advance.state.order == [ids[0], ids[2], ids[3], ids[1]])
        #expect(advance.state.delaying.map(\.id) == [ids[1]])
    }

    @Test("When the last strip that isn't delaying starts, the delayed strips below it return")
    func roundEnd() {
        var (state, ids) = fight()
        state.startDelay(ids[1])
        state = TurnAdvancer.next(state).state
        #expect(state.currentID == ids[2])
        #expect(state.delaying.isEmpty)
        state = TurnAdvancer.next(state).state
        #expect(state.currentID == ids[1])
        #expect(state.round == 1)
        state = TurnAdvancer.next(state).state
        #expect(state.currentID == ids[0])
        #expect(state.round == 2)
    }

    @Test("The last strip delaying on its own turn waits into the next round")
    func lastStripDelays() {
        var (state, ids) = fight()
        state = TurnAdvancer.next(TurnAdvancer.next(state).state).state
        state.startDelay(ids[2])
        state = TurnAdvancer.next(state).state
        #expect(state.round == 2)
        #expect(state.currentID == ids[0])
        #expect(state.delaying.map(\.id) == [ids[2]])
    }

    @Test("Returning keeps the strip's place")
    func endDelay() {
        let (state, ids) = delayedGoblin()
        var returned = state
        returned.endDelay(ids[0])
        #expect(returned.order == state.order)
        #expect(returned.delaying.isEmpty)
        #expect(returned.currentID == ids[1])
    }

    @Test("A delayed strip can be dragged down but not up")
    func dragDirection() {
        var (state, ids) = fight()
        state[ids[1]]?.isDelaying = true
        state.move(ids[1], toIndex: 0)
        #expect(state.order == ids)
        state.move(ids[1], toIndex: 2)
        #expect(state.order == [ids[0], ids[2], ids[1]])
        state.move(ids[2], toIndex: 0)
        #expect(state.order == [ids[2], ids[0], ids[1]])
    }

    @Test("Moving to the bench ends a delay")
    func bench() {
        var (state, ids) = delayedGoblin()
        state.moveToBench(ids[0])
        #expect(state.order == [ids[1], ids[2]])
        #expect(state[ids[0]]?.place == .bench)
        #expect(state[ids[0]]?.isDelaying == false)
    }

    @Test("A session saved with a combatant off the ladder delaying comes back just below the current strip")
    func oldSessionDecodes() throws {
        let (state, ids) = fight()
        var json = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(state)) as? [String: Any])
        var combatants = try #require(json["combatants"] as? [[String: Any]])
        let index = try #require(combatants.firstIndex { $0["name"] as? String == "Ogre" })
        combatants[index]["place"] = "delaying"
        combatants[index]["isDelaying"] = nil
        json["combatants"] = combatants
        json["order"] = [ids[0], ids[1]].map(\.uuidString)
        let decoded = try JSONDecoder().decode(CombatState.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.order == [ids[0], ids[2], ids[1]])
        #expect(decoded[ids[2]]?.place == .ladder)
        #expect(decoded.delaying.map(\.id) == [ids[2]])
    }

    /// The goblin delayed on its turn: Valeros is up, with the goblin waiting just below.
    private func delayedGoblin() -> (CombatState, [UUID]) {
        var (state, ids) = fight()
        state.startDelay(ids[0])
        return (TurnAdvancer.next(state).state, ids)
    }
}
