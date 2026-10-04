import XCTest

/// The board's notes panes: editable, collapsible with a tap on the header.
final class NotesUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--demo", "board"]
        app.launch()
    }

    func testNotesPanesCollapseAndKeepWhatIsTyped() {
        let encounterHeader = app.buttons["Encounter Notes"]
        XCTAssertTrue(encounterHeader.waitForExistence(timeout: 10))
        let planned = app.textViews.matching(NSPredicate(format: "value CONTAINS 'trapdoor'")).firstMatch
        XCTAssertTrue(planned.exists)
        encounterHeader.tap()
        XCTAssertTrue(waitUntil { !planned.exists })
        encounterHeader.tap()
        XCTAssertTrue(planned.waitForExistence(timeout: 3))

        let creatureNotes = app.textViews.element(boundBy: 0)
        creatureNotes.tap()
        creatureNotes.typeText("Flees at half HP")
        XCTAssertTrue(app.textViews.matching(NSPredicate(format: "value CONTAINS 'Flees at half HP'"))
            .firstMatch.waitForExistence(timeout: 3))
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
