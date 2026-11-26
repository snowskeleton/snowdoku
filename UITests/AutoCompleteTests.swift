import XCTest

/// The Finish button: offered only above Beginner, with no mistakes, when few cells remain.
final class AutoCompleteTests: XCTestCase {
    static let hard = "...165...6.....7......93.........3.98.19...7...5..7.1.........61.8.3...4..95.4.3."
    static let beginner = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"

    override func setUp() { continueAfterFailure = false }

    func launch(_ puzzle: String, leaving: Int, wrong: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-puzzle", puzzle, "-prefill", "\(leaving)"] + (wrong ? ["-wrong"] : [])
        app.launch()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH '1,'")).firstMatch.waitForExistence(timeout: 10))
        return app
    }

    func testFinishSolvesThePuzzle() {
        let app = launch(Self.hard, leaving: 10)
        let finish = app.buttons["Finish puzzle"]
        XCTAssertTrue(finish.waitForExistence(timeout: 5))
        finish.tap()
        XCTAssertTrue(app.staticTexts["Solved!"].waitForExistence(timeout: 5))
    }

    func testNotOfferedWithAMistake() {
        let app = launch(Self.hard, leaving: 10, wrong: true)
        XCTAssertFalse(app.buttons["Finish puzzle"].waitForExistence(timeout: 3))
    }

    func testNotOfferedWithManyCellsLeft() {
        let app = launch(Self.hard, leaving: 30)
        XCTAssertFalse(app.buttons["Finish puzzle"].waitForExistence(timeout: 3))
    }

    func testNotOfferedOnBeginner() {
        let app = launch(Self.beginner, leaving: 10)
        XCTAssertFalse(app.buttons["Finish puzzle"].waitForExistence(timeout: 3))
    }
}
