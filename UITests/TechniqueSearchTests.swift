import XCTest

/// The technique library is searchable, and a hint links to its technique's page.
final class TechniqueSearchTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func testSearchFiltersTheLibrary() {
        let app = XCUIApplication()
        app.launch()
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 10))
        tabs.buttons["Techniques"].tap()

        XCTAssertTrue(app.navigationBars["Techniques"].waitForExistence(timeout: 5))
        let field = app.searchFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("wing")
        XCTAssertTrue(app.staticTexts["X-Wing"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Naked Single"].exists)
        app.staticTexts["X-Wing"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["X-Wing"].waitForExistence(timeout: 5))
    }

    func testHintLinksToTheTechnique() {
        let app = XCUIApplication()
        app.launchArguments = ["-drill", "xWing", "-hint", "1"]
        app.launch()
        let learn = app.buttons["Learn X-Wing"]
        XCTAssertTrue(learn.waitForExistence(timeout: 10))
        learn.tap()
        XCTAssertTrue(app.navigationBars["X-Wing"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Play a puzzle that needs it"].exists, "no practice buttons mid-game")
        app.buttons["Done"].tap()
        XCTAssertTrue(app.staticTexts["Find the next move: X-Wing"].waitForExistence(timeout: 5))
    }

    func testNudgeDoesNotNameTheTechnique() {
        let app = XCUIApplication()
        app.launchArguments = ["-drill", "xWing", "-hint", "0"]
        app.launch()
        XCTAssertTrue(app.buttons["Show more"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Learn X-Wing"].exists)
    }
}
