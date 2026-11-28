import XCTest

/// Spotlight questions (the singles lessons and drills): only the spotlit cells take input, a
/// wrong digit bounces back with the rule it breaks, and the answer completes the question.
final class SpotlightLessonTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }

    func cells(_ app: XCUIApplication, _ predicate: String) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH 'Row ' AND " + predicate))
    }

    func digit(_ app: XCUIApplication, _ d: Int) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(d),")).firstMatch
    }

    func position(_ e: XCUIElement) -> String {
        e.label.components(separatedBy: ", ").prefix(2).joined(separator: ", ") + ","
    }

    /// "Which digit fits in this cell?": the cell starts selected, taps elsewhere don't move the
    /// question, wrong digits bounce with their clash named, and the right one finishes it.
    func testNakedSingleQuestion() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetGames", "-resetCampaign", "-campaign", "nakedSingle", "lesson0"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Which digit fits in this cell?"].waitForExistence(timeout: 15))
        let focus = cells(app, "label ENDSWITH 'in focus'")
        XCTAssertEqual(focus.count, 1, "an exact naked single question lights one cell")
        let pos = position(focus.firstMatch)
        let target = cells(app, "label BEGINSWITH '\(pos)'").firstMatch
        XCTAssertTrue(target.isSelected)

        // An empty cell outside the question can't be selected.
        let outside = cells(app, "label ENDSWITH 'empty'").firstMatch
        XCTAssertTrue(outside.exists)
        outside.tap()
        XCTAssertTrue(target.isSelected, "a tap outside the spotlight doesn't take the selection")
        XCTAssertFalse(outside.isSelected)

        var bounced = 0
        for d in 1...9 {
            digit(app, d).tap()
            if app.staticTexts["That's it!"].waitForExistence(timeout: 1) {
                XCTAssertTrue(target.label.contains(", \(d)"), target.label)
                XCTAssertGreaterThan(bounced, 0, "eight digits are wrong, and the right one wasn't 1 every time")
                XCTAssertTrue(app.staticTexts["1 of 5."].exists)
                return
            }
            // Wrong: the board is unchanged, the cell still selected, and the clash is named.
            bounced += 1
            XCTAssertTrue(target.label.hasSuffix("empty, in focus"), target.label)
            XCTAssertTrue(target.isSelected)
            let coach = app.staticTexts["coachText"]
            XCTAssertTrue(coach.waitForExistence(timeout: 2))
            XCTAssertTrue(coach.label.hasPrefix("There's already a \(d) in "), coach.label)
        }
        XCTFail("no digit answered the question")
    }

    /// "Where does the 5 go in this box?": the digit starts armed; only cells in the box take it.
    func testHiddenSingleBoxQuestion() {
        let app = XCUIApplication()
        app.launchArguments = ["-resetGames", "-resetCampaign", "-campaign", "hiddenSingleBox", "lesson0"]
        app.launch()
        let prompt = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Where does the '")).firstMatch
        XCTAssertTrue(prompt.waitForExistence(timeout: 15))
        let d = Int(prompt.label.dropFirst("Where does the ".count).prefix(1))!

        // Outside the box nothing happens, even with the digit armed.
        let outside = cells(app, "label ENDSWITH 'empty'").firstMatch
        let outsidePos = position(outside)
        outside.tap()
        XCTAssertTrue(cells(app, "label BEGINSWITH '\(outsidePos)'").firstMatch.label.hasSuffix("empty"))

        let empties = cells(app, "label ENDSWITH 'empty, in focus'")
        let positions = (0..<empties.count).map { position(empties.element(boundBy: $0)) }
        XCTAssertGreaterThan(positions.count, 1)
        for pos in positions {
            let cell = cells(app, "label BEGINSWITH '\(pos)'").firstMatch
            cell.tap()
            if app.staticTexts["That's it!"].waitForExistence(timeout: 1) {
                XCTAssertTrue(cell.label.contains(", \(d)"), cell.label)
                return
            }
            XCTAssertTrue(cell.label.hasSuffix("empty, in focus"), "a wrong cell bounces: \(cell.label)")
            XCTAssertTrue(app.staticTexts["coachText"].label.hasPrefix("There's already a \(d) in "))
        }
        XCTFail("no cell answered the question")
    }
}
