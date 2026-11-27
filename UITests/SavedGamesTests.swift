import XCTest

/// Each tier keeps its own unfinished game. Going back to a tier with one asks
/// "Continue or new game?", and Continue brings back that tier's game, not the latest.
final class SavedGamesTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func cell(_ app: XCUIApplication, _ r: Int, _ c: Int) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Row \(r), column \(c),")).firstMatch
    }

    /// Taps a tier's New game row, scrolling it clear of the tab bar first.
    func tapTier(_ app: XCUIApplication, _ tier: String) {
        let row = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(tier),")).firstMatch
        app.scroll(to: row)
        var n = 0
        while row.frame.maxY > app.tabBars.firstMatch.frame.minY - 8 && n < 6 { app.swipeUp(velocity: .slow); n += 1 }
        row.tap()
    }

    /// Starts a tier from Home and waits for the board.
    func start(_ app: XCUIApplication, _ tier: String) {
        tapTier(app, tier)
        XCTAssertTrue(app.navigationBars[tier].waitForExistence(timeout: 30))
    }

    func back(_ app: XCUIApplication) {
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Today's puzzle"].waitForExistence(timeout: 5))
    }

    /// Enters `digit` as a note in the first empty cell of row 1 and returns that cell's column.
    func markFirstEmptyCell(_ app: XCUIApplication, digit: Int) -> Int {
        for c in 1...9 where cell(app, 1, c).label.hasSuffix("empty") {
            cell(app, 1, c).tap()
            app.buttons["Note \(digit)"].tap()
            return c
        }
        XCTFail("row 1 has no empty cell"); return 0
    }

    func testEachTierKeepsItsGame() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetGames"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Today's puzzle"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Continue"].exists)

        start(app, "Easy")
        let column = markFirstEmptyCell(app, digit: 7)
        let marked = cell(app, 1, column).label
        XCTAssertTrue(marked.contains("7"), marked)
        back(app)

        start(app, "Hard")
        back(app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Hard ·'")).firstMatch.exists,
                      "Continue offers the most recent game")

        // Easy asks, and Continue restores the Easy game with its note.
        tapTier(app, "Easy")
        XCTAssertTrue(app.staticTexts["Continue or new game?"].waitForExistence(timeout: 5))
        app.buttons["Continue"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Easy"].waitForExistence(timeout: 5))
        XCTAssertEqual(cell(app, 1, column).label, marked)
        back(app)

        // New game replaces it.
        tapTier(app, "Easy")
        XCTAssertTrue(app.buttons["New game"].waitForExistence(timeout: 5))
        app.buttons["New game"].tap()
        XCTAssertTrue(app.navigationBars["Easy"].waitForExistence(timeout: 30))
        XCTAssertFalse(cell(app, 1, column).label.contains("notes"))

        // Saved games survive a relaunch.
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.staticTexts["Continue"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Today's puzzle"].waitForExistence(timeout: 10))
        tapTier(app, "Hard")
        XCTAssertTrue(app.staticTexts["Continue or new game?"].waitForExistence(timeout: 5))
    }
}
