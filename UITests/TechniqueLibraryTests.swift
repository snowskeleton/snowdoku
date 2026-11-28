import XCTest

/// The technique library can be grouped by level or by category, and remembers the choice.
final class TechniqueLibraryTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testSwitchingBetweenDifficultyAndCategory() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.tab("Techniques").waitForExistence(timeout: 10))
        app.tab("Techniques").tap()

        app.buttons["By difficulty"].tap()
        XCTAssertTrue(app.staticTexts["Beginner 1"].waitForExistence(timeout: 5), "one section per level")
        XCTAssertTrue(app.staticTexts["Beginner 2"].exists)
        XCTAssertFalse(app.staticTexts["Beginner"].exists, "no section for the whole tier")
        XCTAssertFalse(app.staticTexts["Singles"].exists)

        app.buttons["By category"].tap()
        XCTAssertTrue(app.staticTexts["Singles"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Beginner 1"].exists, "each row shows its level")
        XCTAssertTrue(app.scroll(to: app.staticTexts["Single-Digit Patterns"]).exists)

        // The choice survives a relaunch.
        app.terminate()
        app.launch()
        XCTAssertTrue(app.tab("Techniques").waitForExistence(timeout: 10))
        app.tab("Techniques").tap()
        XCTAssertTrue(app.staticTexts["Singles"].waitForExistence(timeout: 5))
        app.buttons["By difficulty"].tap()
    }
}
