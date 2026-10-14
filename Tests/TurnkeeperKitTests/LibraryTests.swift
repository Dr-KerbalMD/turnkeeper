import Foundation
import Testing
@testable import TurnkeeperKit

@Suite("Library and merging")
struct LibraryTests {
    private func plannedLibrary() -> (Library, Encounter) {
        var library = Library()
        let campaign = Campaign(name: "PFS Season 7", game: .pathfinder)
        let scenario = Scenario(campaignID: campaign.id, name: "#7-03", variantLabels: ["10–12 CP", "16–18 CP"])
        let encounter = Encounter(scenarioID: scenario.id, name: "A: Docks")
        library.save(campaign)
        library.save(scenario)
        library.save(encounter)
        return (library, encounter)
    }

    /// The library as the other device would have it after a transfer.
    private func transferred(_ library: Library) throws -> Library {
        let package = LibraryPackage(library: library, bestiaryRevision: "abc")
        var received = Library()
        _ = LibraryMerger.merge(try LibraryPackage.decode(package.encoded()).library, into: &received)
        return received
    }

    @Test("New records are added, and a package round-trips exactly")
    func added() throws {
        let (library, _) = plannedLibrary()
        let received = try transferred(library)
        #expect(received.encounters.map(\.id) == library.encounters.map(\.id))
        #expect(received.encounters[0].modifiedAt == library.encounters[0].modifiedAt)
        #expect(received.encounters[0].sharedVersion == library.encounters[0].modifiedAt)
    }

    @Test("A change made on one side fast-forwards the other, without a conflict copy")
    func fastForward() throws {
        let (mac, encounter) = plannedLibrary()
        var ipad = try transferred(mac)
        var edited = ipad.encounters[0]
        edited.notes = "Ambush from the water"
        ipad.save(edited)
        var macAfter = mac
        let summary = LibraryMerger.merge(ipad, into: &macAfter)
        #expect(summary.updated == 1)
        #expect(summary.added + summary.deleted + summary.conflicts == 0)
        #expect(macAfter.encounters.first { $0.id == encounter.id }?.notes == "Ambush from the water")
    }

    @Test("Edits on both sides keep the newer and a conflict copy of the other")
    func conflict() throws {
        var (mac, encounter) = plannedLibrary()
        var ipad = try transferred(mac)
        var onMac = mac.encounters[0]
        onMac.notes = "Mac notes"
        mac.save(onMac)
        var onIPad = ipad.encounters[0]
        onIPad.notes = "iPad notes"
        ipad.save(onIPad)
        let summary = LibraryMerger.merge(ipad, into: &mac)
        #expect(summary.conflicts == 1)
        let names = mac.encounters(in: encounter.scenarioID).map(\.name)
        #expect(names.sorted() == ["A: Docks", "A: Docks (conflict copy)"])
        #expect(mac.encounters.first { $0.id == encounter.id }?.notes == "iPad notes")
    }

    @Test("Deletions carry across")
    func deletion() throws {
        let (mac, encounter) = plannedLibrary()
        var ipad = try transferred(mac)
        ipad.deleteEncounter(encounter.id)
        var macAfter = mac
        #expect(LibraryMerger.merge(ipad, into: &macAfter).deleted == 1)
        #expect(macAfter.encounters(in: encounter.scenarioID).isEmpty)
    }

    @Test("Deleting a campaign marks everything in it deleted")
    func cascade() {
        var (library, _) = plannedLibrary()
        library.deleteCampaign(library.campaigns[0].id)
        #expect(library.activeCampaigns.isEmpty)
        #expect(library.encounters.allSatisfy { $0.isDeleted })
    }

    @Test("A campaign package holds only that campaign")
    func campaignPackage() {
        var (library, _) = plannedLibrary()
        library.save(Campaign(name: "Home game", game: .starfinder))
        let package = LibraryPackage.campaign(library.campaigns[0].id, from: library, bestiaryRevision: "")
        #expect(package.library.campaigns.map(\.name) == ["PFS Season 7"])
        #expect(package.library.encounters.count == 1)
    }

    @Test("A package from a newer format is refused")
    func newerFormat() throws {
        var package = LibraryPackage(library: Library(), bestiaryRevision: "")
        package.format = 99
        let data = try package.encoded()
        #expect(throws: LibraryError.newerFormat(99)) { try LibraryPackage.decode(data) }
    }

    @Test("Custom creatures travel with their campaign and are found by key")
    func customCreatures() throws {
        var (library, _) = plannedLibrary()
        let campaign = library.campaigns[0]
        let custom = CustomCreature(campaignID: campaign.id, game: .pathfinder, name: "Gwibble")
        library.save(custom)
        #expect(library.customCreature(key: custom.key)?.creature.name == "Gwibble")
        #expect(CustomCreature.isCustomKey(custom.key))
        let package = LibraryPackage.campaign(campaign.id, from: library, bestiaryRevision: "")
        #expect(package.library.customCreatures.map(\.id) == [custom.id])
        library.deleteCampaign(campaign.id)
        #expect(library.customCreature(key: custom.key) == nil)
    }

    @Test("A library missing newer kinds of records, or with an unreadable record, still loads")
    func lenientLoading() throws {
        let saved = #"{"campaigns":[{"id":"5A1C3A2E-0000-4000-8000-000000000003","name":"Old","game":"pf2e","#
            + #""modifiedAt":0},{"broken":true}],"parties":[]}"#
        let library = try JSONDecoder().decode(Library.self, from: Data(saved.utf8))
        #expect(library.campaigns.map(\.name) == ["Old"])
        #expect(library.customCreatures.isEmpty && library.sessions.isEmpty)
    }

    @Test("Copying a variant gives new slot IDs")
    func copyVariant() {
        var encounter = Encounter(scenarioID: UUID(), name: "B")
        var low = EncounterVariant(label: "Low")
        low.slots = [EncounterSlot(creatureKey: "goblin")]
        encounter.setVariant(low)
        encounter.copyVariant(from: "Low", to: "High")
        #expect(encounter.variant("High").slots.map(\.creatureKey) == ["goblin"])
        #expect(encounter.variant("High").slots[0].id != low.slots[0].id)
    }
}

@Suite("Change clock")
struct ChangeClockTests {
    @Test("Stamps always move forward, even in quick succession")
    func increasing() {
        let stamps = (0..<1000).map { _ in ChangeClock.now() }
        #expect(zip(stamps, stamps.dropFirst()).allSatisfy { $0 < $1 })
    }
}
