import XCTest

/// Setup no longer rolls for creatures, and Begin Combat warns about anyone without an initiative.
final class InitiativeUITests: XCTestCase {
    func testBeginCombatWarnsAboutMissingInitiative() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "setup"]
        app.launch()
        let begin = app.buttons["Begin Combat"]
        XCTAssertTrue(begin.waitForExistence(timeout: 10))
        begin.tap()
        let warning = app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "no initiative yet"))
        XCTAssertTrue(warning.firstMatch.waitForExistence(timeout: 5))
        app.buttons["Go Back"].tap()
        XCTAssertTrue(begin.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Next"].exists)
    }
}
