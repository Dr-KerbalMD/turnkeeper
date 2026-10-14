import Bestiary
import Foundation
import Testing
@testable import TurnkeeperKit

@Suite("Player characters")
struct PlayerCharacterTests {
    private func linkedMember() -> PartyMember {
        var member = PartyMember(name: "Ignatius")
        var sheet = Creature(key: "", name: "Dr Ignatius Constaline", game: .pathfinder)
        sheet.defenses.armorClass = 33
        sheet.defenses.hitPoints = 15  // Demiplane's PDF gets max HP wrong.
        member.sheet = sheet
        member.link = CharacterLink(source: .demiplane, characterID: "999a5a39", game: .pathfinder)
        return member
    }

    @Test("A linked member's card is its sheet under its key and name, with the GM's max HP")
    func creature() throws {
        var member = linkedMember()
        let card = try #require(PlayerCharacter.creature(for: member))
        #expect(card.key == "pc.\(member.id.uuidString)" && card.name == "Ignatius")
        #expect(card.kind == .character && card.defenses.armorClass == 33)
        #expect(card.defenses.hitPoints == 0)
        member.maxHitPoints = 188
        #expect(PlayerCharacter.creature(for: member)?.defenses.hitPoints == 188)
    }

    @Test("A quick PC has no card")
    func quickPC() {
        #expect(PlayerCharacter.creature(for: PartyMember(name: "Kyra")) == nil)
    }

    @Test("Keys lead back to the member")
    func keys() {
        let member = PartyMember(name: "Kyra")
        let key = PlayerCharacter.key(for: member)
        #expect(PlayerCharacter.isKey(key) && PlayerCharacter.memberID(fromKey: key) == member.id)
        #expect(!PlayerCharacter.isKey("custom.1") && PlayerCharacter.memberID(fromKey: "goblin") == nil)
        #expect(PlayerCharacter.memberID(fromKey: "pc.not-a-uuid") == nil)
    }

    @Test("Linked PCs join a fight with their keys, quick PCs without, and both stay PCs")
    func combatSetup() {
        let party = Party(campaignID: UUID(), name: "Table", level: 15,
                          members: [linkedMember(), PartyMember(name: "Kyra")])
        let state = CombatSetup.state(for: EncounterVariant(label: "Base"), party: party) { _ in nil }
        #expect(state.combatants.map(\.creatureKey) == [PlayerCharacter.key(for: party.members[0]), ""])
        #expect(state.combatants.allSatisfy { $0.kind == .playerCharacter && !$0.tracksHitPoints })
    }

    @Test("A linked member round-trips, and members saved before sheets still load")
    func coding() throws {
        var member = linkedMember()
        member.maxHitPoints = 188
        let decoded = try JSONDecoder().decode(PartyMember.self, from: JSONEncoder().encode(member))
        #expect(decoded == member)
        let old = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","name":"Kyra","level":3}"#
        let quick = try JSONDecoder().decode(PartyMember.self, from: Data(old.utf8))
        #expect(quick.sheet == nil && quick.link == nil && quick.maxHitPoints == nil && quick.level == 3)
    }
}
