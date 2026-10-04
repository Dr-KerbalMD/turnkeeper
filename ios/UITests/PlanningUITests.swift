import XCTest

/// Planning and player-view checks against the demo library.
final class PlanningUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    /// Two buttons in one form row once both fired: closing the bestiary opened the custom NPC sheet.
    func testClosingTheBestiaryOpensNothingElse() {
        app.launchArguments = ["--demo", "planner"]
        app.launch()
        XCTAssertTrue(app.navigationBars["A: Ambush on the Docks"].waitForExistence(timeout: 10))
        let addCreature = app.buttons["Add Creature…"]
        for _ in 0..<8 where !addCreature.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(addCreature.isHittable)
        addCreature.tap()
        XCTAssertTrue(app.navigationBars["Bestiary"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        XCTAssertFalse(app.navigationBars["New Creature"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.navigationBars["Bestiary"].exists)
    }

    /// Show Players covers the whole screen, hiding the board behind it, and a tap closes it.
    func testShowPlayersFillsTheScreen() {
        app.launchArguments = ["--demo", "board"]
        app.launch()
        let show = app.buttons["Show Players"]
        XCTAssertTrue(show.waitForExistence(timeout: 10))
        show.tap()
        let next = app.buttons["Next"]
        XCTAssertTrue(waitUntil { !next.isHittable })
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(waitUntil { next.isHittable })
    }

    /// A stat block pasted as plain text becomes a custom creature in the encounter, ready to review.
    func testPastingAStatBlockAddsACustomCreature() {
        UIPasteboard.general.string = """
        Gwibble — Creature 3
        Small, Fey
        Perception +9; darkvision
        AC 19; Fort +7, Ref +11, Will +9
        HP 45
        Speed 25 feet
        Melee ◆ jaws +12 (agile), Damage 2d6+4 piercing
        """
        app.launchArguments = ["--demo", "planner"]
        app.launch()
        XCTAssertTrue(app.navigationBars["A: Ambush on the Docks"].waitForExistence(timeout: 10))
        let paste = app.buttons["Paste"]
        for _ in 0..<8 where !paste.isHittable {
            app.swipeUp()
        }
        paste.tap()
        let added = app.alerts["Stat Blocks Added"]
        XCTAssertTrue(added.waitForExistence(timeout: 5))
        XCTAssertTrue(added.staticTexts["Added Gwibble (Creature 3)."].exists)
        added.buttons["Review…"].tap()
        XCTAssertTrue(app.navigationBars["Gwibble"].waitForExistence(timeout: 5))
        app.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Gwibble"].waitForExistence(timeout: 5))
    }

    /// A copied image pasted on a creature's card becomes its art, and can be removed again.
    func testPastingArtworkOnTheCard() throws {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64))
        UIPasteboard.general.image = renderer.image { context in
            UIColor.systemTeal.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
        app.launchArguments = ["--demo", "planner"]
        app.launch()
        XCTAssertTrue(app.navigationBars["A: Ambush on the Docks"].waitForExistence(timeout: 10))
        let card = app.buttons["Card"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.tap()
        let paste = app.navigationBars.buttons["Paste"]
        XCTAssertTrue(paste.waitForExistence(timeout: 5))
        paste.tap()
        let artwork = app.navigationBars.buttons["Artwork"]
        let remove = app.buttons["Remove Pasted Artwork"]
        XCTAssertTrue(waitUntil {
            artwork.tap()
            if remove.waitForExistence(timeout: 1) { return true }
            app.tap()
            return false
        })
        remove.tap()
        artwork.tap()
        XCTAssertTrue(app.buttons["Choose Image…"].waitForExistence(timeout: 3))
        XCTAssertFalse(remove.exists)
    }

    /// A handout gets a pasted image and is shown to the players full screen with its name.
    func testHandoutShownToPlayers() {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 80, height: 60))
        UIPasteboard.general.image = renderer.image { context in
            UIColor.brown.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 80, height: 60))
        }
        app.launchArguments = ["--demo", "planner"]
        app.launch()
        let add = app.buttons["Add Handout"].firstMatch
        XCTAssertTrue(add.waitForExistence(timeout: 10))
        add.tap()
        XCTAssertTrue(app.navigationBars["Handout 1"].waitForExistence(timeout: 5))
        let show = app.buttons["Show Players"]
        XCTAssertFalse(show.isEnabled)
        app.buttons["Paste"].tap()
        XCTAssertTrue(waitUntil { show.isEnabled })
        show.tap()
        XCTAssertTrue(app.staticTexts["Handout 1"].waitForExistence(timeout: 5))
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(waitUntil { show.isHittable })
    }

    /// Each creature row has its own remove button, since swipe-to-delete doesn't exist on the Mac.
    func testRemovingACreatureFromTheEncounter() {
        app.launchArguments = ["--demo", "planner"]
        app.launch()
        let warrior = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Goblin Warrior'")).firstMatch
        XCTAssertTrue(warrior.waitForExistence(timeout: 10))
        sleep(1)
        app.buttons.matching(identifier: "Remove from Encounter").firstMatch.tap()
        XCTAssertTrue(waitUntil { !warrior.exists }, "The Goblin Warrior row is still there after removing it")
    }

    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return condition()
    }
}
