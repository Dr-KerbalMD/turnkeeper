import XCTest

/// Runs the demo fight (`--demo board`) and checks the ladder's swipes: left to right delays a strip, which
/// is asked about before the turn passes it; right to left knocks one out.
final class DelayUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--demo", "board"]
        app.launch()
    }

    func testSwipingToDelayPassesTheTurnAndAsksBeforePassingIt() {
        XCTAssertTrue(app.buttons["Next"].waitForExistence(timeout: 10))
        let current = currentStrip
        XCTAssertTrue(current.waitForExistence(timeout: 5))
        swipe(current, by: 220)
        let delay = app.alerts.buttons["Delay"]
        XCTAssertTrue(delay.waitForExistence(timeout: 5), "Swiping right asked nothing")
        delay.tap()
        dismissReminders()
        let delaying = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Delaying'"))
        XCTAssertTrue(delaying.firstMatch.waitForExistence(timeout: 5), "No strip shows it is delaying")
        attachScreenshot("Delaying")
        app.buttons["Next"].tap()
        let actNow = app.buttons["Act Now"]
        XCTAssertTrue(actNow.waitForExistence(timeout: 5), "Next didn't ask about the delaying strip")
        attachScreenshot("Asked")
        actNow.tap()
        dismissReminders()
        XCTAssertTrue(waitUntil { delaying.firstMatch.exists == false }, "The strip is still delaying after acting")
    }

    func testSwipingLeftKnocksAStripOut() {
        XCTAssertTrue(app.buttons["Next"].waitForExistence(timeout: 10))
        let dying = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS 'Dying'"))
        let before = dying.count
        swipe(currentStrip, by: -220)
        XCTAssertTrue(waitUntil { dying.count > before }, "No strip became dying")
        attachScreenshot("Knocked out")
    }

    /// The strip whose turn it is: the one marked selected.
    private var currentStrip: XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "selected == true")).firstMatch
    }

    /// A quick sideways drag across a strip, like a finger's swipe.
    private func swipe(_ strip: XCUIElement, by distance: CGFloat) {
        let start = strip.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: distance, dy: 0)),
                    withVelocity: .fast, thenHoldForDuration: 0)
    }

    private func dismissReminders() {
        while app.buttons["Got It"].waitForExistence(timeout: 2) { app.buttons["Got It"].tap() }
    }

    private func attachScreenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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
