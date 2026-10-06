import XCTest

/// A PC linked to a character sheet shows a PC battle card with glossary links, while its strip stays
/// the same as a quick PC's: no AC, HP or initiative hints.
final class PlayerCharacterUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--demo", "board"]
        app.launch()
    }

    func testLinkedPCShowsACardButAPlainStrip() {
        let strip = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS 'Valeros' AND NOT (label CONTAINS 'turn')")).firstMatch
        XCTAssertTrue(strip.waitForExistence(timeout: 10))
        XCTAssertFalse(strip.label.contains("AC"), "the strip reads \(strip.label)")
        XCTAssertFalse(strip.label.contains("Perc"), "the strip reads \(strip.label)")
        strip.tap()

        XCTAssertTrue(text(containing: "PC 3").waitForExistence(timeout: 5))
        let charge = app.links["Sudden Charge"].firstMatch
        XCTAssertTrue(charge.waitForExistence(timeout: 5))
        charge.tap()
        XCTAssertTrue(text(containing: "Stride twice").waitForExistence(timeout: 5))
    }

    private func text(containing fragment: String) -> XCUIElement {
        app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", fragment)).firstMatch
    }
}
