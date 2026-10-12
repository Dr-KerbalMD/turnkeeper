import Foundation
import Testing
@testable import CombatPadKit

@Suite("Fight lifecycle")
struct FightLifecycleTests {
    private func combatant(_ name: String, _ kind: CombatantKind = .creature, side: Side = .enemy,
                           place: PadPlace = .ladder) -> Combatant {
        var combatant = Combatant(kind: kind, name: name, side: side)
        combatant.place = place
        return combatant
    }

    @Test("A fight has started once someone has initiative or combat has begun")
    func hasStarted() {
        var state = CombatState(combatants: [combatant("Orc")])
        #expect(!state.hasStarted)
        state.setInitiative(12, for: state.combatants[0].id)
        #expect(state.hasStarted)
    }

    @Test("Only ladder combatants without initiative are listed, in ladder order")
    func missingInitiative() {
        let kyra = combatant("Kyra", .playerCharacter)
        let orc = combatant("Orc")
        let wolf = combatant("Wolf", place: .bench)
        var state = CombatState(combatants: [kyra, orc, wolf])
        state.setInitiative(15, for: orc.id)
        #expect(state.combatantsWithoutInitiative.map(\.name) == ["Kyra"])
    }

    @Test("Victory needs every joined enemy at 0 HP; the bench, hazards and allies don't count")
    func allEnemiesDown() {
        var orc = combatant("Orc")
        orc.damageTaken = 20
        var goblin = combatant("Goblin")
        goblin.isDelaying = true
        goblin.damageTaken = 6
        let reserve = combatant("Reserve", place: .bench)
        let pit = combatant("Pit", .hazard)
        let guide = combatant("Guide", side: .ally)
        let state = CombatState(combatants: [orc, goblin, reserve, pit, guide])
        #expect(state.allEnemiesDown { $0.name == "Orc" ? 20 : 6 })
        #expect(!state.allEnemiesDown { _ in 30 })
        #expect(!CombatState(combatants: [guide]).allEnemiesDown { _ in 1 })
    }

    @Test("Finished and in-progress sessions, and the lookup for the unfinished one")
    func sessions() {
        let encounterID = UUID()
        let context = SessionContext(campaignID: UUID(), encounterID: encounterID, variantLabel: "Base", name: "A")
        var session = CombatSession(context: context, state: CombatState(combatants: [combatant("Orc")]))
        #expect(!session.isInProgress)
        session.state.setInitiative(10, for: session.state.combatants[0].id)
        #expect(session.isInProgress)
        var library = Library()
        library.save(session)
        #expect(library.unfinishedSession(encounterID: encounterID, variantLabel: "Base")?.id == session.id)
        #expect(library.unfinishedSession(encounterID: encounterID, variantLabel: "Harder") == nil)
        session.finishedAt = Date()
        library.save(session)
        #expect(library.unfinishedSession(encounterID: encounterID, variantLabel: "Base") == nil)
    }

    @Test("Sessions saved before finishing existed still decode, as unfinished")
    func decodesOldSessions() throws {
        let context = SessionContext(campaignID: UUID(), encounterID: UUID(), variantLabel: "Base", name: "A")
        let session = CombatSession(context: context, state: CombatState())
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(session)) as? [String: Any] ?? [:]
        json.removeValue(forKey: "finishedAt")
        json.removeValue(forKey: "partyID")
        let decoded = try JSONDecoder().decode(CombatSession.self, from: JSONSerialization.data(withJSONObject: json))
        #expect(!decoded.isFinished)
    }
}

@Suite("Voice entry target")
struct InitiativeTargetTests {
    @Test("Entry walks down the ladder, unless the GM chose a strip")
    func target() {
        var state = CombatState(combatants: ["Kyra", "Goblin", "Ezren"].map { Combatant(kind: .creature, name: $0) })
        let ids = state.ladder.map(\.id)
        #expect(state.initiativeTarget(chosen: nil) == ids[0])
        state.setInitiative(18, for: ids[0])
        #expect(state.initiativeTarget(chosen: nil) == ids[1])
        #expect(state.initiativeTarget(chosen: ids[0]) == ids[0])
        #expect(state.initiativeTarget(chosen: UUID()) == ids[1])
        state.setInitiative(12, for: ids[1])
        state.setInitiative(9, for: ids[2])
        #expect(state.initiativeTarget(chosen: nil) == nil)
    }
}
