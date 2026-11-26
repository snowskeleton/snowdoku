import XCTest

/// The technique library can be grouped by difficulty or by category, and remembers the choice.
final class TechniqueLibraryTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testSwitchingBetweenDifficultyAndCategory() {
        let app = XCUIApplication()
        app.launch()
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 10))
        tabs.buttons["Techniques"].tap()

        app.buttons["By difficulty"].tap()
        XCTAssertTrue(app.staticTexts["Beginner"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Singles"].exists)

        app.buttons["By category"].tap()
        XCTAssertTrue(app.staticTexts["Singles"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Beginner"].exists, "each row shows its tier")
        XCTAssertTrue(app.scroll(to: app.staticTexts["Single-Digit Patterns"]).exists)

        // The choice survives a relaunch.
        app.terminate()
        app.launch()
        XCTAssertTrue(tabs.waitForExistence(timeout: 10))
        tabs.buttons["Techniques"].tap()
        XCTAssertTrue(app.staticTexts["Singles"].waitForExistence(timeout: 5))
        app.buttons["By difficulty"].tap()
    }
}
