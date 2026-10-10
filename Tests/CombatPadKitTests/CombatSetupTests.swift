import Bestiary
import Foundation
import Testing
@testable import CombatPadKit

@Suite("Starting a fight")
struct CombatSetupTests {
    private func entry(
        _ key: String, _ name: String, level: Int, kind: CreatureKind = .creature
    ) -> BestiaryIndexEntry {
        var creature = Creature(key: key, name: name, game: .pathfinder)
        creature.level = level
        creature.kind = kind
        return BestiaryIndexEntry(creature: creature)
    }

    private var bestiary: [String: BestiaryIndexEntry] {
        ["goblin": entry("goblin", "Goblin Warrior", level: -1), "boss": entry("boss", "Goblin War Chanter", level: 1),
         "pit": entry("pit", "Drowning Pit", level: 3, kind: .hazard)]
    }

    @Test("Creatures are numbered across slots and templates, benched ones wait, and PCs join")
    func combatants() {
        var variant = EncounterVariant(label: "Base")
        var goblins = EncounterSlot(creatureKey: "goblin")
        goblins.count = 2
        var reserve = EncounterSlot(creatureKey: "goblin")
        reserve.startsOnBench = true
        reserve.template = .weak  // A weak stack shares the numbering.
        variant.slots = [goblins, reserve, EncounterSlot(creatureKey: "pit")]
        let party = Party(campaignID: UUID(), name: "Table 1", level: 1, members: [PartyMember(name: "Kyra")])
        let state = CombatSetup.state(for: variant, party: party) { bestiary[$0] }
        #expect(state.combatants.map(\.name) == ["Kyra", "Goblin Warrior 1", "Goblin Warrior 2", "Goblin Warrior 3",
                                                 "Drowning Pit"])
        #expect(state.bench.map(\.name) == ["Goblin Warrior 3"])
        #expect(state.combatants.last?.kind == .hazard)
        #expect(state.combatants.last?.magnet == .gray)
        #expect(state.phase == .setup)
    }

    @Test("Planned conditions and temporary HP start the fight, as separate copies for each creature")
    func startingState() {
        var slot = EncounterSlot(creatureKey: "goblin")
        slot.count = 2
        slot.conditions = [AppliedCondition(slug: "enfeebled", value: 1)]
        slot.temporaryHitPoints = 5
        var variant = EncounterVariant(label: "Base")
        variant.slots = [slot]
        let state = CombatSetup.state(for: variant, party: nil) { bestiary[$0] }
        #expect(state.combatants.allSatisfy { $0.temporaryHitPoints == 5 })
        #expect(state.combatants.map { $0.condition("enfeebled")?.value } == [1, 1])
        #expect(state.combatants[0].conditions[0].id != state.combatants[1].conditions[0].id)
    }

    @Test("Slots saved before starting conditions existed still decode")
    func oldSlots() throws {
        let saved = #"{"id":"5A1C3A2E-0000-4000-8000-000000000002","creatureKey":"goblin","count":2}"#
        let slot = try JSONDecoder().decode(EncounterSlot.self, from: Data(saved.utf8))
        #expect(slot.count == 2 && slot.conditions.isEmpty && slot.temporaryHitPoints == 0)
    }

    @Test("Away players wait on the bench and aren't counted in the budget")
    func awayPlayers() throws {
        var away = PartyMember(name: "Merisiel")
        away.isAway = true
        let party = Party(campaignID: UUID(), name: "Table", level: 3, members: [PartyMember(name: "Kyra"), away])
        let state = CombatSetup.state(for: EncounterVariant(label: "Base"), party: party) { _ in nil }
        #expect(state.ladder.map(\.name) == ["Kyra"])
        #expect(state.bench.map(\.name) == ["Merisiel"])
        #expect(party.budget.partySize == 1)
        let saved = #"{"id":"5A1C3A2E-0000-4000-8000-000000000001","name":"Ezren"}"#
        let decoded = try JSONDecoder().decode(PartyMember.self, from: Data(saved.utf8))
        #expect(!decoded.isAway)
    }

    @Test("A variant's XP uses template-adjusted levels and leaves out allies")
    func experience() {
        var variant = EncounterVariant(label: "Base")
        var elite = EncounterSlot(creatureKey: "boss")
        elite.template = .elite
        var goblins = EncounterSlot(creatureKey: "goblin")
        goblins.count = 2
        var guide = EncounterSlot(creatureKey: "boss")
        guide.side = .ally
        variant.slots = [elite, goblins, guide]
        let budget = EncounterBudget(partyLevel: 1, partySize: 4)
        // Elite level-1 boss is level 2 (+1: 60 XP); goblins at -1 are party level -2 (20 XP each).
        #expect(budget.experience(of: variant) { bestiary[$0] } == 100)
    }

    @Test("Initiative is a d20 roll plus the modifier")
    func rolls() {
        var generator = SystemRandomNumberGenerator()
        let rolls = (0..<200).map { _ in CombatSetup.rollInitiative(modifier: 5, using: &generator) }
        #expect(rolls.allSatisfy { (6...25).contains($0) })
    }
}
