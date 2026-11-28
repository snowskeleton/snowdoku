import XCTest

/// Each tier keeps its own unfinished game. Going back to a tier with one asks
/// "Continue or new game?", and Continue brings back that tier's game, not the latest.
final class SavedGamesTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func cell(_ app: XCUIApplication, _ r: Int, _ c: Int) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Row \(r), column \(c),")).firstMatch
    }

    /// Taps a row (a tier in Free Play or a level in a tier), scrolling it clear of the tab bar first.
    func tapRow(_ app: XCUIApplication, _ id: String) {
        let row = app.buttons[id]
        app.scroll(to: row)
        var n = 0
        while row.frame.maxY > app.tabBars.firstMatch.frame.minY - 8 && n < 6 { app.swipeUp(velocity: .slow); n += 1 }
        row.tap()
    }

    /// Opens a tier's level list from Free Play.
    func openTier(_ app: XCUIApplication, _ tier: String) {
        tapRow(app, "tier.\(tier)")
        XCTAssertTrue(app.navigationBars[tier].waitForExistence(timeout: 5))
    }

    /// Taps a level's row in its tier's list ("Easy", 2 → "level.easy2").
    func tapLevel(_ app: XCUIApplication, _ tier: String, _ n: Int) {
        tapRow(app, "level.\(tier.lowercased())\(n)")
    }

    /// Opens Free Play from Home.
    func openFreePlay(_ app: XCUIApplication) {
        app.staticTexts["Free Play"].tap()
        XCTAssertTrue(app.navigationBars["Free Play"].waitForExistence(timeout: 5))
    }

    /// Starts a level from Free Play (tier, then level) and waits for the board.
    func start(_ app: XCUIApplication, _ tier: String, _ n: Int) {
        openTier(app, tier)
        tapLevel(app, tier, n)
        XCTAssertTrue(app.navigationBars["\(tier) \(n)"].waitForExistence(timeout: 30))
    }

    /// Back one screen, to the screen titled `title`.
    func back(_ app: XCUIApplication, to title: String) {
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars[title].waitForExistence(timeout: 5))
    }

    /// Back from the board to Free Play, through the tier's level list.
    func backToFreePlay(_ app: XCUIApplication, from tier: String) {
        back(app, to: tier)
        back(app, to: "Free Play")
    }

    /// Back from Free Play to Home.
    func home(_ app: XCUIApplication) {
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

        openFreePlay(app)
        start(app, "Easy", 2)
        let column = markFirstEmptyCell(app, digit: 7)
        let marked = cell(app, 1, column).label
        XCTAssertTrue(marked.contains("7"), marked)
        backToFreePlay(app, from: "Easy")

        start(app, "Hard", 1)
        backToFreePlay(app, from: "Hard")
        home(app)
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Hard 1 ·'")).firstMatch.exists,
                      "Continue offers the most recent game")
        openFreePlay(app)

        // Any Easy level asks, and Continue restores the Easy game with its note.
        openTier(app, "Easy")
        tapLevel(app, "Easy", 1)
        XCTAssertTrue(app.staticTexts["Continue or new game?"].waitForExistence(timeout: 5))
        app.buttons["Continue"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Easy 2"].waitForExistence(timeout: 5))
        XCTAssertEqual(cell(app, 1, column).label, marked)
        back(app, to: "Easy")

        // A new game replaces it.
        tapLevel(app, "Easy", 1)
        XCTAssertTrue(app.buttons["New Easy 1 game"].waitForExistence(timeout: 5))
        app.buttons["New Easy 1 game"].tap()
        XCTAssertTrue(app.navigationBars["Easy 1"].waitForExistence(timeout: 30))
        XCTAssertFalse(cell(app, 1, column).label.contains("notes"))

        // Saved games survive a relaunch.
        app.terminate()
        app.launchArguments = []
        app.launch()
        XCTAssertTrue(app.staticTexts["Continue"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Today's puzzle"].waitForExistence(timeout: 10))
        openFreePlay(app)
        openTier(app, "Hard")
        tapLevel(app, "Hard", 3)
        XCTAssertTrue(app.staticTexts["Continue or new game?"].waitForExistence(timeout: 5))
    }

    /// Free Play is two steps: a tier, then one of its levels. The board says which level it is,
    /// and the level list marks the one in progress.
    func testTierThenLevel() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetGames"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Today's puzzle"].waitForExistence(timeout: 10))
        openFreePlay(app)
        openTier(app, "Medium")
        for n in 1...4 { XCTAssertTrue(app.buttons["level.medium\(n)"].exists, "Medium \(n)") }
        XCTAssertFalse(app.buttons["level.medium5"].exists)
        XCTAssertTrue(app.buttons["level.medium1"].label.contains("X-Wing"), app.buttons["level.medium1"].label)

        tapLevel(app, "Medium", 3)
        XCTAssertTrue(app.navigationBars["Medium 3"].waitForExistence(timeout: 30))
        XCTAssertTrue(app.staticTexts["Medium 3"].exists, "the header names the level")
        back(app, to: "Medium")
        XCTAssertTrue(app.buttons["level.medium3"].label.contains("In progress"), app.buttons["level.medium3"].label)
        XCTAssertFalse(app.buttons["level.medium1"].label.contains("In progress"))
        back(app, to: "Free Play")
        XCTAssertTrue(app.buttons["tier.Medium"].label.contains("In progress"), app.buttons["tier.Medium"].label)
    }
}
