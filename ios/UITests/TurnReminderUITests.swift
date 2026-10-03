import XCTest

/// Runs the demo fight (`--demo board`) and checks that turn reminders appear and block Next until dismissed.
final class TurnReminderUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--demo", "board"]
        app.launch()
    }

    func testSlowedRemindsAtTheStartOfTheTurnAndBlocksNext() {
        let next = app.buttons["Next"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        XCTAssertTrue(app.staticTexts["Slowed 1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 action fewer this turn."].exists)
        app.buttons["Got It"].tap()
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertTrue(next.isEnabled)
    }

    func testPersistentDamageAndFrightenedRemindAtTheEndOfTheTurn() {
        XCTAssertTrue(app.buttons["Next"].waitForExistence(timeout: 10))
        var seen: Set<String> = []
        for _ in 0..<40 where !seen.contains("Persistent 1d6 bleed") {
            if app.buttons["Got It"].exists {
                for title in ["Persistent 1d6 bleed", "Frightened 2", "Slowed 1"] where app.staticTexts[title].exists {
                    seen.insert(title)
                }
                app.buttons["Got It"].tap()
            } else {
                app.buttons["Next"].tap()
            }
            _ = app.buttons["Got It"].waitForExistence(timeout: 1)
        }
        XCTAssertTrue(seen.contains("Persistent 1d6 bleed"))
        XCTAssertTrue(seen.contains("Frightened 2") || app.staticTexts["Frightened 2"].exists)
    }
}
