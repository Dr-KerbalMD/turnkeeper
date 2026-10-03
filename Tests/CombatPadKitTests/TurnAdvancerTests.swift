import Foundation
import Testing
@testable import CombatPadKit

@Suite("Turn advancing and reminders")
struct TurnAdvancerTests {
    /// A started fight: a goblin at 17, Valeros at 12 and an ogre at 8, plus any events.
    private func fight(events: [EncounterEvent] = []) -> (CombatState, [UUID]) {
        let goblin = Combatant(kind: .creature, name: "Goblin")
        let valeros = Combatant(kind: .playerCharacter, name: "Valeros")
        let ogre = Combatant(kind: .creature, name: "Ogre")
        var state = CombatState(combatants: [valeros, ogre, goblin], events: events)
        state.setInitiative(17, for: goblin.id)
        state.setInitiative(12, for: valeros.id)
        state.setInitiative(8, for: ogre.id)
        state.beginCombat()
        return (state, [goblin.id, valeros.id, ogre.id])
    }

    @Test("Begin combat sorts by initiative and starts round 1 with the highest")
    func beginCombat() {
        let (state, ids) = fight()
        #expect(state.order == ids)
        #expect(state.round == 1)
        #expect(state.currentID == ids[0])
    }

    @Test("On tied initiative enemies go first")
    func ties() {
        let pc = Combatant(kind: .playerCharacter, name: "Kyra")
        let enemy = Combatant(kind: .creature, name: "Orc")
        var state = CombatState(combatants: [pc, enemy])
        state.setInitiative(10, for: pc.id)
        state.setInitiative(10, for: enemy.id)
        #expect(state.order == [enemy.id, pc.id])
    }

    @Test("Wrapping around ends the round, starts the next, and fires round events in order")
    func roundWrap() {
        let end = EncounterEvent(label: "Round ends", trigger: .endOfRound)
        let start = EncounterEvent(label: "Reinforcements", trigger: .startOfRound, occurrence: .onlyRound(2))
        var (state, ids) = fight(events: [start, end])
        state = TurnAdvancer.next(state).state
        state = TurnAdvancer.next(state).state
        let advance = TurnAdvancer.next(state)
        #expect(advance.state.round == 2)
        #expect(advance.state.currentID == ids[0])
        #expect(advance.reminders.map(\.title) == ["Round ends", "Reinforcements"])
    }

    @Test("An event at initiative 15 fires once a round, between 17 and 12")
    func initiativeEvent() {
        let collapse = EncounterEvent(label: "Ceiling collapses", trigger: .initiative(15))
        var (state, _) = fight(events: [collapse])
        var fired: [Int] = []
        for _ in 0..<6 {
            let advance = TurnAdvancer.next(state)
            if advance.reminders.contains(where: { $0.title == "Ceiling collapses" }) {
                fired.append(state.order.firstIndex(of: state.currentID!)!)
            }
            state = advance.state
        }
        #expect(fired == [0, 0])
    }

    @Test("An event at the top of the order fires after the wrap, in the new round")
    func eventAboveEveryone() {
        let lair = EncounterEvent(label: "Lair action", trigger: .initiative(20), occurrence: .onlyRound(2))
        var (state, _) = fight(events: [lair])
        state = TurnAdvancer.next(state).state
        state = TurnAdvancer.next(state).state
        #expect(TurnAdvancer.next(state).reminders.map(\.title) == ["Lair action"])
    }

    @Test("Every 2 rounds from round 3 fires in rounds 3, 5 and 7")
    func occurrence() {
        let every = EventOccurrence.every(interval: 2, start: 3)
        #expect((1...8).filter(every.includes) == [3, 5, 7])
    }

    @Test("Slowed reminds at the start of the turn")
    func slowed() {
        var (state, ids) = fight()
        state.addCondition(AppliedCondition(slug: "slowed", value: 1), to: ids[1])
        let reminders = TurnAdvancer.next(state).reminders
        #expect(reminders.map(\.title) == ["Slowed 1"])
        #expect(reminders.first?.combatantID == ids[1])
    }

    @Test("Frightened goes down at the end of the turn, and the change can be undone")
    func frightened() throws {
        var (state, ids) = fight()
        state.addCondition(AppliedCondition(slug: "frightened", value: 2), to: ids[0])
        var advance = TurnAdvancer.next(state)
        #expect(advance.state[ids[0]]?.condition("frightened")?.value == 1)
        let undo = try #require(advance.reminders.first?.actions.first)
        advance.state.apply(undo)
        #expect(advance.state[ids[0]]?.condition("frightened")?.value == 2)
    }

    @Test("Persistent damage reminds at the end of the turn; damage and recovery apply")
    func persistentDamage() throws {
        var (state, ids) = fight()
        state.addCondition(.persistent(DamagePart(formula: "1d6", type: "bleed", isPersistent: true)), to: ids[0])
        var advance = TurnAdvancer.next(state)
        let reminder = try #require(advance.reminders.first)
        #expect(reminder.title == "Persistent 1d6 bleed")
        advance.state.apply(reminder.actions[0], amount: 4)
        #expect(advance.state[ids[0]]?.damageTaken == 4)
        advance.state.apply(reminder.actions[1])
        #expect(advance.state[ids[0]]?.conditions.isEmpty == true)
    }

    @Test("Stunned 2 loses 2 actions and ends")
    func stunned() {
        var (state, ids) = fight()
        state.addCondition(AppliedCondition(slug: "stunned", value: 2), to: ids[1])
        let advance = TurnAdvancer.next(state)
        #expect(advance.reminders.first?.text == "Loses 2 actions this turn; stunned ends.")
        #expect(advance.state[ids[1]]?.condition("stunned") == nil)
    }

    @Test("Dying recovery checks change dying, and reaching 0 adds wounded")
    func dying() {
        var (state, ids) = fight()
        state.addCondition(AppliedCondition(slug: "dying", value: 1), to: ids[1])
        state.apply(.recoveryCheck(.success, combatantID: ids[1]))
        #expect(state[ids[1]]?.condition("dying") == nil)
        #expect(state[ids[1]]?.condition("wounded")?.value == 1)
        state.addCondition(AppliedCondition(slug: "dying", value: 2), to: ids[1])
        state.apply(.recoveryCheck(.criticalFailure, combatantID: ids[1]))
        #expect(state.isDead(ids[1]))
    }

    @Test("A duration arrow counts down at its anchor's turn and reports when it ends")
    func durations() {
        var (state, ids) = fight()
        state.addDuration(DurationMarker(label: "Bless", rounds: 2, anchor: ids[0], moment: .startOfTurn))
        var titles: [String] = []
        for _ in 0..<6 {
            let advance = TurnAdvancer.next(state)
            titles += advance.reminders.map(\.title)
            state = advance.state
        }
        #expect(titles == ["Bless ends"])
        #expect(state.durations.isEmpty)
    }

    @Test("Delay passes the turn; returning acts now at that point in the order")
    func delay() {
        var (state, ids) = fight()
        state.startDelay(ids[0])
        #expect(state.currentID == ids[1])
        #expect(state.delaying.map(\.id) == [ids[0]])
        state = TurnAdvancer.next(state).state
        state.endDelay(ids[0])
        #expect(state.currentID == ids[0])
        #expect(state.order == [ids[1], ids[0], ids[2]])
    }

    @Test("Benched creatures come in at their initiative")
    func bench() {
        var (state, ids) = fight()
        var wolf = Combatant(kind: .creature, name: "Wolf")
        wolf.place = .bench
        state.combatants.append(wolf)
        state.bringIn(wolf.id, initiative: 10)
        #expect(state.order == [ids[0], ids[1], wolf.id, ids[2]])
    }

    @Test("Damage comes off temporary HP first; healing can't go below 0 damage")
    func hitPoints() {
        var (state, ids) = fight()
        state.grantTemporaryHitPoints(5, to: ids[0])
        state.applyDamage(8, to: ids[0])
        #expect(state[ids[0]]?.temporaryHitPoints == 0)
        #expect(state[ids[0]]?.damageTaken == 3)
        state.heal(10, on: ids[0])
        #expect(state[ids[0]]?.damageTaken == 0)
        state.applyDamage(5, to: ids[1])
        #expect(state[ids[1]]?.damageTaken == 0)
    }
}
