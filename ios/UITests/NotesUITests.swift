import XCTest

/// The board's right half: notes panes that edit and collapse, and the card that flips to show its art.
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
        // Right after launch the board is still settling; a tap then can land before the header is ready.
        XCTAssertTrue(waitUntil { encounterHeader.isHittable })
        encounterHeader.tap()
        XCTAssertTrue(waitUntil { !planned.exists }, describe(encounterHeader))
        // A second tap a fraction of a second after the first, on a header that just moved, is dropped;
        // people don't tap that fast, but the test does.
        Thread.sleep(forTimeInterval: 1)
        encounterHeader.tap()
        XCTAssertTrue(planned.waitForExistence(timeout: 3), describe(encounterHeader))

        let creatureNotes = app.textViews.element(boundBy: 0)
        creatureNotes.tap()
        creatureNotes.typeText("Flees at half HP")
        XCTAssertTrue(app.textViews.matching(NSPredicate(format: "value CONTAINS 'Flees at half HP'"))
            .firstMatch.waitForExistence(timeout: 3))
    }

    /// A tap on the card shows the flip icon, which shows the GM the art; the next turn turns the card back to
    /// its stat block.
    func testFlipCardShowsArtUntilTheTurnMoves() {
        let flip = revealCardIcons(named: "Flip Card")
        flip.tap()
        let back = app.buttons["Show Stat Block"]
        XCTAssertTrue(back.waitForExistence(timeout: 3))
        XCTAssertFalse(perceptionLine.exists)
        app.buttons["Next"].tap()
        XCTAssertTrue(waitUntil { !back.exists })
    }

    /// The full-screen icon shows the card over the board; a tap there shows its exit icon, which closes it.
    func testFullScreenCardCoversTheBoard() {
        revealCardIcons(named: "Full Screen").tap()
        let next = app.buttons["Next"]
        XCTAssertTrue(waitUntil { !next.isHittable })
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8)).tap()
        let exit = app.buttons["Exit Full Screen"]
        XCTAssertTrue(waitUntil { exit.isHittable })
        exit.tap()
        XCTAssertTrue(waitUntil { next.isHittable })
    }

    private var perceptionLine: XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Perception'")).firstMatch
    }

    /// Taps the card's Perception line, which has no links, so the corner icons show.
    @discardableResult
    private func revealCardIcons(named name: String) -> XCUIElement {
        XCTAssertTrue(perceptionLine.waitForExistence(timeout: 10))
        perceptionLine.tap()
        let icon = app.buttons[name]
        XCTAssertTrue(icon.waitForExistence(timeout: 3))
        return icon
    }

    private func describe(_ header: XCUIElement) -> String {
        let views = app.textViews.allElementsBoundByIndex.map { view in
            "\(view.frame) \((view.value as? String)?.prefix(12) ?? "")"
        }
        return "header \(header.frame) hittable \(header.isHittable); text views \(views)"
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
