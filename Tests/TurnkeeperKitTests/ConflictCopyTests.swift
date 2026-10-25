import Foundation
import Testing
@testable import TurnkeeperKit

@Suite("Conflict copies only for edits made on both devices")
struct ConflictCopyTests {
    /// Syncs nearby: each device sends its library, then merges the one it received.
    @discardableResult
    private func sync(_ mac: inout Library, _ ipad: inout Library) -> (mac: MergeSummary, ipad: MergeSummary) {
        mac = mac.sending()
        ipad = ipad.sending()
        let (macSent, ipadSent) = (mac, ipad)
        return (LibraryMerger.merge(ipadSent, into: &mac), LibraryMerger.merge(macSent, into: &ipad))
    }

    /// A Mac library with Signal Jammer, and the iPad after their first sync.
    private func synced() -> (mac: Library, ipad: Library) {
        var mac = Library(), ipad = Library()
        mac.save(Encounter(scenarioID: UUID(), name: "A. Signal Jammer"))
        sync(&mac, &ipad)
        return (mac, ipad)
    }

    private func editNotes(_ library: inout Library, _ notes: String) {
        var encounter = library.encounters[0]
        encounter.notes = notes
        library.save(encounter)
    }

    private func names(_ library: Library) -> [String] { library.encounters.map(\.name).sorted() }

    @Test("Editing on one device across several syncs carries each edit across without a copy")
    func oneDevice() {
        var (mac, ipad) = synced()
        for notes in ["Jammer on the roof", "Jammer in the basement", "Two jammers"] {
            editNotes(&mac, notes)
            let summaries = sync(&mac, &ipad)
            #expect(summaries.mac.conflicts == 0 && summaries.ipad.conflicts == 0)
            #expect(ipad.encounters.map(\.notes) == [notes])
        }
        editNotes(&ipad, "Edited on the iPad")
        #expect(sync(&mac, &ipad).mac.conflicts == 0)
        #expect(names(mac) == ["A. Signal Jammer"] && mac.encounters[0].notes == "Edited on the iPad")
    }

    @Test("Edits on both devices make one copy, the same on both, and later syncs add none")
    func bothDevices() {
        var (mac, ipad) = synced()
        editNotes(&ipad, "iPad notes")
        editNotes(&mac, "Mac notes")
        let summaries = sync(&mac, &ipad)
        #expect(summaries.mac.conflicts == 1 && summaries.ipad.conflicts == 1)
        sync(&mac, &ipad)
        let expected = ["A. Signal Jammer", "A. Signal Jammer (conflict copy)"]
        #expect(names(mac) == expected && names(ipad) == expected)
        #expect(Set(mac.encounters.map(\.id)) == Set(ipad.encounters.map(\.id)))
        let original = mac.encounters.first { $0.name == "A. Signal Jammer" }
        let copy = mac.encounters.first { $0.name.hasSuffix("(conflict copy)") }
        #expect(original?.notes == "Mac notes" && copy?.notes == "iPad notes")
    }

    @Test("A one-way file keeps working: the version sent back unchanged is known")
    func files() throws {
        var mac = Library(), ipad = Library()
        mac.save(Encounter(scenarioID: UUID(), name: "A. Signal Jammer"))
        let toIpad = try LibraryPackage.decode(LibraryPackage(library: mac.sending(), bestiaryRevision: "").encoded())
        mac = mac.sending()
        LibraryMerger.merge(toIpad.library, into: &ipad)
        editNotes(&mac, "Edited after sending")
        let summary = LibraryMerger.merge(ipad.sending(), into: &mac)
        #expect(summary.conflicts == 0 && !summary.changedAnything)
        #expect(mac.encounters.map(\.notes) == ["Edited after sending"])
    }

    @Test("A save that changes nothing isn't an edit")
    func unchangedSave() {
        var (mac, _) = synced()
        let before = mac.encounters[0].modifiedAt
        mac.save(mac.encounters[0])
        #expect(mac.encounters[0].modifiedAt == before)
        editNotes(&mac, "Changed")
        #expect(mac.encounters[0].modifiedAt > before)
    }

    @Test("Shared versions are capped, keeping the newest")
    func capped() {
        var (mac, ipad) = synced()
        for round in 0..<40 {
            editNotes(&mac, "Round \(round)")
            sync(&mac, &ipad)
        }
        let versions = mac.encounters[0].sharedVersions ?? []
        #expect(versions.count == Encounter.sharedVersionLimit)
        #expect(versions.last == mac.encounters[0].modifiedAt)
    }

    @Test("A record saved before shared versions were kept still loads, knowing the version it last received")
    func olderRecord() throws {
        let (_, ipad) = synced()
        let json = try #require(String(data: try JSONEncoder().encode(ipad.encounters[0]), encoding: .utf8))
        let olderJSON = json.replacing(#/"sharedVersions":\[[^\]]*\],?/#, with: "")
        #expect(olderJSON != json)
        let older = try JSONDecoder().decode(Encounter.self, from: Data(olderJSON.utf8))
        #expect(older.sharedVersions == nil && older.hasShared(ipad.encounters[0].modifiedAt))
    }

    @Test("The difficulty last run comes from the scenario's latest fight, so starting one edits no scenario")
    func lastRun() {
        var library = Library()
        var scenario = Scenario(campaignID: UUID(), name: "1-08 Compliance Protocol",
                                variantLabels: VariantScheme.easierBaseHarder.labels)
        scenario.lastVariantLabel = "Easier"
        library.save(scenario)
        #expect(library.lastRunVariantLabel(in: scenario) == "Easier")
        let encounter = Encounter(scenarioID: scenario.id, name: "A. Signal Jammer")
        library.save(encounter)
        for label in ["Base", "Harder"] {
            let context = SessionContext(campaignID: scenario.campaignID, encounterID: encounter.id,
                                         variantLabel: label, name: label)
            library.save(CombatSession(context: context, state: CombatState()))
        }
        #expect(library.lastRunVariantLabel(in: scenario) == "Harder")
    }
}
