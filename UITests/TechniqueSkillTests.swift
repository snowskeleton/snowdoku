import XCTest

/// Each correct digit counts toward the technique it needed, and Statistics shows the record.
final class TechniqueSkillTests: XCTestCase {
    // Solution row 9: 3 4 5 2 8 6 1 7 9. Prefilling leaves r9c6 and r9c7 empty.
    static let classic = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"

    override func setUp() { continueAfterFailure = false }

    func cell(_ app: XCUIApplication, _ r: Int, _ c: Int) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Row \(r), column \(c),")).firstMatch
    }

    func digit(_ app: XCUIApplication, _ d: Int) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(d),")).firstMatch
    }

    func testSolvedMovesShowInStatistics() {
        let app = XCUIApplication()
        app.launchArguments = ["-puzzle", Self.classic, "-prefill", "2"]
        app.launch()
        XCTAssertTrue(cell(app, 9, 6).waitForExistence(timeout: 10))
        cell(app, 9, 6).tap(); digit(app, 6).tap()
        cell(app, 9, 7).tap(); digit(app, 1).tap()
        XCTAssertTrue(app.staticTexts["Solved!"].waitForExistence(timeout: 5))

        // Stats persist: relaunch onto Home rather than navigating back, which differs by device.
        sleep(1)
        app.terminate()
        app.launchArguments = []
        app.launch()
        // A tab bar on iPhone, a top bar or sidebar on iPad.
        let statistics = app.buttons.matching(identifier: "Statistics").firstMatch
        XCTAssertTrue(statistics.waitForExistence(timeout: 10))
        statistics.tap()
        let all = app.scroll(to: app.buttons["All techniques"])
        XCTAssertTrue(all.exists)
        all.tap()
        XCTAssertTrue(app.navigationBars["Techniques"].waitForExistence(timeout: 5))
        let row = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "percent unaided")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
    }
}
