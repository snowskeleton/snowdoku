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
        XCTAssertTrue(app.tab("Play").waitForExistence(timeout: 10))

        app.tab("Techniques").tap()
        XCTAssertTrue(app.navigationBars["Techniques"].waitForExistence(timeout: 5))

        app.tab("Statistics").tap()
        XCTAssertTrue(app.navigationBars["Statistics"].waitForExistence(timeout: 5))

        app.tab("Settings").tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.scroll(to: app.switches["Show timer"]).exists)

        app.tab("Play").tap()
        XCTAssertTrue(app.staticTexts["Today's puzzle"].waitForExistence(timeout: 5))
    }

    func testPracticeFromTechniquesOpensBoardInPlayTab() {
        XCTAssertTrue(app.tab("Play").waitForExistence(timeout: 10))
        app.tab("Techniques").tap()
        app.staticTexts["Naked Single"].firstMatch.tap()
        app.scroll(to: app.buttons["Play a puzzle that needs it"]).tap()

        let cell = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Row 1, column 1,")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 60), "practice game should open on the board")
        XCTAssertFalse(app.tab("Play").exists && app.tab("Play").isHittable, "tabs are hidden during a game")

        app.navigationBars.buttons.firstMatch.tap() // back
        XCTAssertTrue(app.tab("Play").waitForExistence(timeout: 5))
        XCTAssertTrue(app.tab("Play").isSelected)
    }
}
