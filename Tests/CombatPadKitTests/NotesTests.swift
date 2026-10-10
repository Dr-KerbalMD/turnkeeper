import Bestiary
import Foundation
import Testing
@testable import CombatPadKit

@Suite("Creature notes")
struct CreatureNoteTests {
    @Test("A note covers its creature in one scenario, and merges on its own")
    func notes() throws {
        var library = Library()
        let campaign = Campaign(name: "Season 7", game: .pathfinder)
        let docks = Scenario(campaignID: campaign.id, name: "#7-03")
        let other = Scenario(campaignID: campaign.id, name: "#7-04")
        [docks, other].forEach { library.save($0) }
        library.save(campaign)
        #expect(library.creatureNote(scenarioID: docks.id, subject: "goblin").text.isEmpty)
        var note = library.creatureNote(scenarioID: docks.id, subject: "goblin")
        note.text = "Carries the vault key"
        library.save(note)
        #expect(library.creatureNote(scenarioID: docks.id, subject: "goblin").text == "Carries the vault key")
        #expect(library.creatureNote(scenarioID: other.id, subject: "goblin").text.isEmpty)

        let package = LibraryPackage.campaign(campaign.id, from: library, bestiaryRevision: "")
        var ipad = Library()
        _ = LibraryMerger.merge(try LibraryPackage.decode(package.encoded()).library, into: &ipad)
        var edited = ipad.creatureNote(scenarioID: docks.id, subject: "goblin")
        edited.text = "Carries the vault key and a lantern"
        ipad.save(edited)
        let summary = LibraryMerger.merge(ipad, into: &library)
        #expect(summary.updated == 1 && summary.conflicts == 0)
        #expect(library.creatureNote(scenarioID: docks.id, subject: "goblin").text.hasSuffix("lantern"))
        library.deleteScenario(docks.id)
        #expect(library.creatureNote(scenarioID: docks.id, subject: "goblin").text.isEmpty)
    }

    @Test("A session saved with scratch notes still loads")
    func oldSession() throws {
        let session = CombatSession(context: SessionContext(campaignID: UUID(), encounterID: UUID(),
                                                            variantLabel: "Base", name: "Docks"),
                                    state: CombatState(combatants: []))
        var json = try #require(try JSONSerialization.jsonObject(with: JSONEncoder().encode(session))
            as? [String: Any])
        json["scratchNotes"] = "old notes"
        let decoded = try JSONDecoder().decode(CombatSession.self,
                                               from: JSONSerialization.data(withJSONObject: json))
        #expect(decoded.id == session.id)
    }
}

@Suite("Card and notes split")
struct SplitLayoutTests {
    @Test("Heights follow the fractions and always fill the space")
    func heights() {
        let layout = SplitLayout()
        #expect(layout.heights(total: 1000) == [600, 200, 200])
        let hidden = layout.heights(total: 1000, visible: [0, 2])
        #expect(hidden[1] == 0 && abs(hidden[0] - 750) < 0.001 && abs(hidden.reduce(0, +) - 1000) < 0.001)
    }

    @Test("Dragging moves space between neighbors and keeps the card's minimum")
    func dragging() {
        var layout = SplitLayout()
        layout.drag(above: 0, below: 1, by: 100, total: 1000)
        #expect(layout.heights(total: 1000).map { $0.rounded() } == [700, 100, 200])
        layout.drag(above: 0, below: 1, by: -900, total: 1000)
        #expect(layout.heights(total: 1000)[0].rounded() == 200)
        #expect(abs(layout.fractions.reduce(0, +) - 1) < 0.000_001)
    }

    @Test("A notes pane dragged below its minimum collapses, and opens again with a tap")
    func collapsing() {
        var layout = SplitLayout()
        layout.drag(above: 1, below: 2, by: 150, total: 1000)
        #expect(layout.collapsed == [SplitLayout.encounterNotes])
        let heights = layout.heights(total: 1000)
        #expect(heights[2] == SplitLayout.headerHeight && abs(heights.reduce(0, +) - 1000) < 0.001)
        layout.toggle(SplitLayout.encounterNotes)
        #expect(layout.collapsed.isEmpty)
        layout.toggle(SplitLayout.card)
        #expect(layout.collapsed.isEmpty)
        layout.reset()
        #expect(layout == SplitLayout())
    }

    @Test("With creature notes hidden, the card and encounter notes share the space, and its share is kept")
    func hiddenPane() {
        var layout = SplitLayout()
        let visible: Set<Int> = [SplitLayout.card, SplitLayout.encounterNotes]
        layout.drag(above: 0, below: 2, by: -150, total: 1000, visible: visible)
        let heights = layout.heights(total: 1000, visible: visible)
        #expect(heights[0].rounded() == 600 && heights[2].rounded() == 400)
        #expect(abs(layout.fractions[1] - 0.2) < 0.000_001)
        layout.drag(above: 0, below: 2, by: 10, total: 1000, visible: [0, 1])
        #expect(abs(layout.fractions[1] - 0.2) < 0.000_001)
    }

    @Test("Saved layouts round-trip, and bad ones fall back to the default")
    func saved() throws {
        var layout = SplitLayout()
        layout.drag(above: 0, below: 1, by: -100, total: 1000)
        let decoded = try JSONDecoder().decode(SplitLayout.self, from: JSONEncoder().encode(layout))
        #expect(decoded == layout)
        #expect(SplitLayout(fractions: [1, 2]).fractions == SplitLayout.defaultFractions)
        #expect(SplitLayout(fractions: [0, 0, 0]).fractions == SplitLayout.defaultFractions)
    }
}
