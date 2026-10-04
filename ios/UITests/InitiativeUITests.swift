import XCTest

/// Setup no longer rolls for creatures, Begin Combat warns about anyone without an initiative, and the
/// hold-to-talk button enters totals strip by strip.
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

    /// With scripted speech: each hold sets the highlighted strip and moves on; a miss shows a message rather
    /// than the keypad; tapping a strip chooses it.
    func testHoldToTalkWalksDownTheLadder() {
        let app = XCUIApplication()
        app.launchArguments = ["--demo", "setup", "--fake-voice", "seventeen,mumble,twenty"]
        app.launch()
        let talk = app.otherElements["Hold to Say Initiative"].firstMatch
        let status = app.staticTexts["voiceStatus"]
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        let first = status.label.replacingOccurrences(of: "Next: ", with: "")
        XCTAssertFalse(first.isEmpty)

        hold(talk, app: app)
        let advanced = waitUntil { status.label.hasPrefix("Next: ") && status.label != "Next: \(first)" }
        XCTAssertTrue(advanced, "status stayed \(status.label)")
        let second = status.label.replacingOccurrences(of: "Next: ", with: "")

        hold(talk, app: app)
        XCTAssertTrue(waitUntil { status.label.contains("Didn't catch a number") })
        XCTAssertFalse(app.buttons["Roll"].exists, "a miss must not open the keypad")

        // The tile reads as one element whose label starts with the combatant's initiative and name.
        let chosen = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS 'Merisiel' AND NOT (label CONTAINS 'Next')")).firstMatch
        XCTAssertNotEqual(second, "Merisiel")
        chosen.tap()
        XCTAssertTrue(waitUntil { status.label == "Next: Merisiel" }, "status is \(status.label)")
        hold(talk, app: app)
        XCTAssertTrue(waitUntil { status.label == "Next: \(second)" })
    }

    private func hold(_ element: XCUIElement, app: XCUIApplication) {
        let target = element.exists ? element : app.descendants(matching: .any)["Hold to Say Initiative"].firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        target.press(forDuration: 0.6)
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
