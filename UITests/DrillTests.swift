import XCTest

/// Technique drills: a mid-solve position whose next move is the technique. Making the move
/// shows the result card; "Next drill" starts another.
final class DrillTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func board(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Row 1, column 1,")).firstMatch
    }

    func testMakingTheMoveCompletesTheDrill() {
        let app = XCUIApplication()
        app.launchArguments = ["-drill", "pointing", "-hint", "4"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Find the next move: Pointing"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["That's the Pointing!"].exists)

        app.buttons["Apply"].tap()
        XCTAssertTrue(app.staticTexts["That's the Pointing!"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Found: Pointing"].exists)

        app.buttons["Next drill"].tap()
        XCTAssertTrue(app.staticTexts["Find the next move: Pointing"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["That's the Pointing!"].exists)
    }

    func testKeepSolvingDismissesTheCard() {
        let app = XCUIApplication()
        app.launchArguments = ["-drill", "xWing", "-hint", "4"]
        app.launch()
        XCTAssertTrue(app.buttons["Apply"].waitForExistence(timeout: 10))
        app.buttons["Apply"].tap()
        XCTAssertTrue(app.buttons["Keep solving"].waitForExistence(timeout: 5))
        app.buttons["Keep solving"].tap()
        XCTAssertFalse(app.buttons["Keep solving"].waitForExistence(timeout: 2))
        XCTAssertTrue(app.staticTexts["Found: X-Wing"].exists)
    }

    func testTechniquePageExplainsAndStartsADrill() {
        let app = XCUIApplication()
        app.launch()
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 10))
        tabs.buttons["Techniques"].tap()
        app.scroll(to: app.staticTexts["X-Wing"].firstMatch).tap()
        XCTAssertTrue(app.navigationBars["X-Wing"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "rectangle")).firstMatch.exists,
                      "the How it works guide is shown")
        app.scroll(to: app.buttons["Drill: find the next move"]).tap()
        XCTAssertTrue(app.staticTexts["Find the next move: X-Wing"].waitForExistence(timeout: 10))
        XCTAssertTrue(board(app).exists)
    }
}
