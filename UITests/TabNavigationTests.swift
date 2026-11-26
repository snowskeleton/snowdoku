import XCTest

/// Techniques, Statistics and Settings live in their own tabs; starting a game from any
/// tab lands on the board in the Play tab, with the tab bar hidden.
final class TabNavigationTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testTabsShowTheirScreens() {
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 10))

        tabs.buttons["Techniques"].tap()
        XCTAssertTrue(app.navigationBars["Techniques"].waitForExistence(timeout: 5))

        tabs.buttons["Statistics"].tap()
        XCTAssertTrue(app.navigationBars["Statistics"].waitForExistence(timeout: 5))

        tabs.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["Show timer"].exists)

        tabs.buttons["Play"].tap()
        XCTAssertTrue(app.staticTexts["Today's puzzle"].waitForExistence(timeout: 5))
    }

    func testPracticeFromTechniquesOpensBoardInPlayTab() {
        let tabs = app.tabBars.firstMatch
        XCTAssertTrue(tabs.waitForExistence(timeout: 10))
        tabs.buttons["Techniques"].tap()
        app.staticTexts["Naked Single"].firstMatch.tap()
        app.buttons["Practice with a puzzle that needs it"].tap()

        let cell = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Row 1, column 1,")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 60), "practice game should open on the board")
        XCTAssertFalse(app.tabBars.firstMatch.isHittable, "tab bar is hidden during a game")

        app.navigationBars.buttons.firstMatch.tap() // back
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(tabs.buttons["Play"].isSelected)
    }
}
