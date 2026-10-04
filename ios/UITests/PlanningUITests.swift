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

    private func waitUntil(timeout: TimeInterval = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        return condition()
    }
}
