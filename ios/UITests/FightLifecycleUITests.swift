import XCTest

/// Closing the board must never lose a fight: Run (now Resume) comes back to it as it was.
final class FightLifecycleUITests: XCTestCase {
    func testClosingAndResumingKeepsTheFight() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "board"]
        app.launch()
        let next = app.buttons["Next"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        if app.buttons["Got It"].waitForExistence(timeout: 3) { app.buttons["Got It"].tap() }
        XCTAssertTrue(turnLabel("Kyra's turn", in: app).waitForExistence(timeout: 5))

        app.buttons["Close"].tap()
        let encounter = app.buttons["A: Ambush on the Docks"].firstMatch
        if encounter.waitForExistence(timeout: 5) {
            encounter.tap()
        } else {
            app.staticTexts["A: Ambush on the Docks"].firstMatch.tap()
        }
        let resume = app.buttons["Resume"]
        XCTAssertTrue(resume.waitForExistence(timeout: 5))
        resume.tap()
        XCTAssertTrue(turnLabel("Kyra's turn", in: app).waitForExistence(timeout: 5))
    }

    private func turnLabel(_ text: String, in app: XCUIApplication) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }
}
