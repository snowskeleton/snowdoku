import XCTest

/// The campaign: steps open in order, a level counts only without hints, and Continue picks up
/// where the player left off (campaign or free play).
final class CampaignTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    /// The one empty cell `-prefill 1` leaves.
    func emptyCell(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(
            format: "label BEGINSWITH 'Row ' AND (label ENDSWITH 'empty' OR label CONTAINS 'notes')")).firstMatch
    }

    /// Fills the last empty cell by trying digits until the puzzle is solved.
    func solveLastCell(_ app: XCUIApplication) {
        let cell = emptyCell(app)
        XCTAssertTrue(cell.waitForExistence(timeout: 15))
        // Its label changes as digits go in, so find it again by position ("Row r, column c,").
        let position = cell.label.components(separatedBy: ", ").prefix(2).joined(separator: ", ") + ","
        let target = app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", position)).firstMatch
        for d in 1...9 {
            target.tap()
            app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(d),")).firstMatch.tap()
            if app.staticTexts["Solved!"].waitForExistence(timeout: 1) || app.staticTexts["Chapter complete!"].exists { return }
        }
        XCTFail("no digit solved the puzzle")
    }

    func continueSubtitle(_ app: XCUIApplication) -> String {
        let button = app.buttons["continue"]
        XCTAssertTrue(button.waitForExistence(timeout: 10))
        return button.label
    }

    func testStepsOpenInOrder() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetGames", "-resetCampaign"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Campaign"].waitForExistence(timeout: 10))
        app.staticTexts["Campaign"].tap()
        let first = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '1. Full House'")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        XCTAssertTrue(first.isEnabled)
        let second = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '2. '")).firstMatch
        XCTAssertFalse(second.isEnabled, "chapter 2 opens only after chapter 1's boss")
        first.tap()
        XCTAssertTrue(app.navigationBars["Full House"].waitForExistence(timeout: 5))
        // The singles chapters open with the guided lessons.
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'First Steps'")).firstMatch.isEnabled)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Less Help'")).firstMatch.isEnabled)
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Spotlight 1'")).firstMatch.isEnabled)
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Boss'")).firstMatch.isEnabled,
                      "the boss is open at once, so a chapter can be skipped")
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Endless'")).firstMatch.isEnabled)
    }

    func testSolvingWithoutHintsOpensTheNextStep() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetGames", "-campaignDone", "4", "-campaign", "pointing", "spotlight0", "-prefill", "1"]
        app.launch()
        solveLastCell(app)
        XCTAssertTrue(app.buttons["Next level"].exists)
        app.buttons["Back"].tap()
        XCTAssertTrue(continueSubtitle(app).contains("Pointing · Spotlight 2"), continueSubtitle(app))
    }

    func testAHintedSolveAsksForAnother() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetGames", "-campaignDone", "4", "-campaign", "pointing", "spotlight0", "-prefill", "1"]
        app.launch()
        XCTAssertTrue(app.buttons["Hint"].waitForExistence(timeout: 15))
        app.buttons["Hint"].tap()
        solveLastCell(app)
        XCTAssertTrue(app.buttons["Try another"].exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'without hints'")).firstMatch.exists)
        app.buttons["Back"].tap()
        XCTAssertTrue(continueSubtitle(app).contains("Pointing · Spotlight 1"), continueSubtitle(app))
    }

    func testBeatingTheBossOpensTheNextChapter() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetGames", "-campaignDone", "4", "-campaign", "pointing", "boss", "-prefill", "1"]
        app.launch()
        solveLastCell(app)
        XCTAssertTrue(app.staticTexts["Chapter complete!"].exists)
        XCTAssertTrue(app.buttons["Next chapter"].exists)
        app.buttons["Back"].tap()
        XCTAssertTrue(continueSubtitle(app).contains("Claiming"), continueSubtitle(app))
    }

    func testContinueAfterFreePlayStartsAnotherOfThatLevel() throws {
        let app = XCUIApplication()
        // A Beginner puzzle from the bank.
        app.launchArguments = ["-resetGames", "-puzzle",
                               "...35.2.......8.315.......7..8..4..2.5..8.14.1...9..8......2...69......48....697.", "-prefill", "1"]
        app.launch()
        solveLastCell(app)
        app.buttons["Home"].tap()
        let subtitle = continueSubtitle(app)
        // "Beginner 2 · new game": another game of the level just played.
        let level = try XCTUnwrap(subtitle.components(separatedBy: " · ").first)
        XCTAssertTrue(level.hasPrefix("Beginner ") && subtitle.hasSuffix(" · new game"), subtitle)
        app.buttons["continue"].tap()
        XCTAssertTrue(app.navigationBars[level].waitForExistence(timeout: 10))
    }

    func testFreePlayListsTheTiers() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Free Play"].waitForExistence(timeout: 10))
        app.staticTexts["Free Play"].tap()
        XCTAssertTrue(app.navigationBars["Free Play"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Beginner,'")).firstMatch.exists)
    }
}
