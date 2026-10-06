import XCTest

/// Linked words on a battle card open the glossary in a popover, and links in that popover open one more.
final class GlossaryUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--demo", "board"]
        app.launch()
    }

    func testLinksOpenTwoLevelsOfPopovers() {
        let dogslicer = app.links["dogslicer"].firstMatch
        XCTAssertTrue(dogslicer.waitForExistence(timeout: 10))
        dogslicer.tap()
        XCTAssertTrue(text(containing: "crude makeshift blade").waitForExistence(timeout: 5))

        let agile = app.links["agile"].firstMatch
        XCTAssertTrue(waitUntil { agile.exists && agile.isHittable })
        let linksBefore = app.links.count
        agile.tap()
        XCTAssertTrue(text(containing: "multiple attack penalty").waitForExistence(timeout: 5))
        // The second popover is as deep as links go: its words aren't links.
        XCTAssertLessThanOrEqual(app.links.count, linksBefore)
    }

    private func text(containing fragment: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
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
