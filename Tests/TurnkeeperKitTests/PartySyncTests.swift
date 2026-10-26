import Bestiary
import Foundation
import Testing
@testable import TurnkeeperKit

@Suite("Syncing parties member by member")
struct PartySyncTests {
    /// A Mac library with the Gargul party, and the iPad's copy after a sync.
    private func synced() throws -> (mac: Library, ipad: Library) {
        var mac = Library()
        var party = Party(campaignID: UUID(), name: "Gargul", level: 2)
        party.members = ["Varielle", "Eti", "Asu"].map { PartyMember(name: $0) }
        mac.save(party)
        let package = LibraryPackage(library: mac, bestiaryRevision: "")
        var ipad = Library()
        _ = LibraryMerger.merge(try LibraryPackage.decode(package.encoded()).library, into: &ipad)
        return (mac, ipad)
    }

    /// Edits a library's copy of the party and saves it, as the party editor does.
    private func edit(_ library: inout Library, _ change: (inout Party) -> Void) {
        var party = library.parties[0]
        change(&party)
        library.save(party)
    }

    /// Syncs both ways, each device merging the library the other had before the sync.
    private func sync(_ mac: inout Library, _ ipad: inout Library) {
        let (macBefore, ipadBefore) = (mac, ipad)
        _ = LibraryMerger.merge(ipadBefore, into: &mac)
        _ = LibraryMerger.merge(macBefore, into: &ipad)
    }

    private func member(_ name: String, in library: Library) -> PartyMember? {
        library.parties.first?.members.first { $0.name.hasPrefix(name) }
    }

    @Test("Saving stamps only the members that changed")
    func stamps() throws {
        var (mac, _) = try synced()
        let before = mac.parties[0].members
        edit(&mac) { $0.members[1].isAway = true }
        let after = mac.parties[0].members
        #expect(after[0].modifiedAt == before[0].modifiedAt && after[2].modifiedAt == before[2].modifiedAt)
        #expect(after[1].modifiedAt > before[1].modifiedAt)
    }

    @Test("Members edited on different devices keep both edits, and the newer party's name")
    func differentMembers() throws {
        var (mac, ipad) = try synced()
        edit(&ipad) { $0.members[0].playerName = "Sam" }
        edit(&mac) {
            $0.members[1].isAway = true
            $0.name = "Gargul crew"
        }
        sync(&mac, &ipad)
        for library in [mac, ipad] {
            #expect(member("Varielle", in: library)?.playerName == "Sam")
            #expect(member("Eti", in: library)?.isAway == true)
            #expect(library.parties[0].name == "Gargul crew")
        }
        #expect(mac.parties == ipad.parties)
    }

    @Test("A member removed on one device stays removed; one added on the other is kept")
    func addedAndRemoved() throws {
        var (mac, ipad) = try synced()
        edit(&ipad) { $0.members.removeAll { $0.name == "Asu" } }
        edit(&mac) { $0.members.append(PartyMember(name: "Mandor")) }
        sync(&mac, &ipad)
        for library in [mac, ipad] {
            #expect(library.parties[0].members.map(\.name) == ["Varielle", "Eti", "Mandor"])
        }
        #expect(mac.parties == ipad.parties)
        sync(&mac, &ipad)
        #expect(mac.parties[0].members.count == 3)
    }

    @Test("A member edited on one device after being removed on the other comes back")
    func editedAfterRemoval() throws {
        var (mac, ipad) = try synced()
        edit(&ipad) { $0.members.removeAll { $0.name == "Asu" } }
        edit(&mac) { $0.members[2].notes = "Arrives late" }
        sync(&mac, &ipad)
        #expect(member("Asu", in: ipad)?.notes == "Arrives late")
        #expect(ipad.parties[0].removedMembers.isEmpty && mac.parties == ipad.parties)
    }

    @Test("A sheet refreshed on one device survives the same member being marked away on the other")
    func refreshAndAway() throws {
        var (mac, ipad) = try synced()
        let link = CharacterLink(source: .demiplane, characterID: "eti", game: .starfinder,
                                 fetchedAt: Date(timeIntervalSinceNow: -60))
        edit(&mac) { _ = $0.apply(Creature(key: "", name: "Eti", game: .starfinder), link: link,
                                      to: $0.members[1].id) }
        sync(&mac, &ipad)
        var sheet = Creature(key: "", name: "Eti", game: .starfinder)
        sheet.defenses.armorClass = 20
        edit(&ipad) { _ = $0.apply(sheet, link: CharacterLink(source: .demiplane, characterID: "eti",
                                                                   game: .starfinder), to: $0.members[1].id) }
        edit(&mac) { $0.members[1].isAway = true }
        sync(&mac, &ipad)
        for library in [mac, ipad] {
            #expect(member("Eti", in: library)?.isAway == true)
            #expect(member("Eti", in: library)?.sheet?.defenses.armorClass == 20)
        }
    }

    @Test("The same member edited on both devices keeps the newer edit; an unlink isn't undone")
    func sameMember() throws {
        var (mac, ipad) = try synced()
        edit(&mac) { $0.members[0].link = CharacterLink(source: .demiplane, characterID: "v", game: .starfinder) }
        sync(&mac, &ipad)
        edit(&ipad) { $0.members[0].notes = "iPad" }
        edit(&mac) {
            $0.members[0].notes = "Mac"
            $0.members[0].link = nil
        }
        sync(&mac, &ipad)
        #expect(member("Varielle", in: ipad)?.notes == "Mac" && member("Varielle", in: ipad)?.link == nil)
        #expect(mac.parties == ipad.parties)
    }

    @Test("Parties and members saved before member syncing still load")
    func oldParty() throws {
        let saved = #"""
            {"id":"5A1C3A2E-0000-4000-8000-000000000010","campaignID":"5A1C3A2E-0000-4000-8000-000000000011",
             "name":"Table","level":1,"modifiedAt":0,
             "members":[{"id":"5A1C3A2E-0000-4000-8000-000000000012","name":"Ezren"}]}
            """#
        let party = try JSONDecoder().decode(Party.self, from: Data(saved.utf8))
        #expect(party.removedMembers.isEmpty && party.members[0].modifiedAt == .distantPast)
        let copy = try JSONDecoder().decode(Party.self, from: JSONEncoder().encode(party))
        #expect(copy == party)
    }
}
