import XCTest

/// The one-pad layout: a single set of digits with a Digits / Notes / Center switch.
final class PadLayoutTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-puzzle", BoardInputTests.puzzle, "-padLayout", "onePad"]
        app.launch()
        XCTAssertTrue(app.buttons["Digits"].waitForExistence(timeout: 10))
    }

    func cell(_ r: Int, _ c: Int) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Row \(r), column \(c),"))
            .firstMatch
    }

    func bigDigit(_ d: Int) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(d),")).firstMatch
    }

    func testOnePadSwitchesBetweenValuesAndNotes() {
        XCTAssertFalse(app.buttons["Note 4"].exists, "one pad: no separate notes pad")
        XCTAssertFalse(app.buttons["Erase"].exists, "one pad drops Erase")
        let undo = app.buttons["Undo"], hint = app.buttons["Hint"]
        XCTAssertTrue(undo.exists && app.buttons["Fill"].exists && hint.exists)
        XCTAssertGreaterThan(undo.frame.minX, app.buttons["Center"].frame.maxX, "actions come after the mode keys")
        if undo.frame.minY == app.buttons["Digits"].frame.minY && hint.frame.minY == undo.frame.minY {
            XCTAssertGreaterThan(hint.frame.minX, undo.frame.maxX, "wide: one row of keys")
        } else {
            XCTAssertGreaterThan(hint.frame.minY, undo.frame.maxY, "narrow: actions are the pad's last column")
        }
        cell(1, 3).tap()
        bigDigit(4).tap()
        XCTAssertEqual(cell(1, 3).label, "Row 1, column 3, 4")

        app.buttons["Notes"].tap()
        XCTAssertTrue(app.buttons["Notes"].isSelected)
        cell(1, 4).tap()
        app.buttons["Note 6"].tap()
        app.buttons["Note 8"].tap()
        XCTAssertEqual(cell(1, 4).label, "Row 1, column 4, notes 6 8", "Notes mode enters notes and keeps the selection")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "one pad, notes"; shot.lifetime = .keepAlways
        add(shot)

        // Digit-first: an armed digit follows the switch.
        cell(1, 4).tap() // deselect
        app.buttons["Note 9"].tap()
        cell(1, 6).tap()
        XCTAssertEqual(cell(1, 6).label, "Row 1, column 6, notes 9")
        app.buttons["Digits"].tap()
        cell(1, 7).tap()
        XCTAssertEqual(cell(1, 7).label, "Row 1, column 7, 9", "switching to Digits makes the armed 9 a value")
    }

    func testCenterNotesAreDrawnPerCell() {
        app.buttons["Center"].tap()
        cell(1, 3).tap()
        app.buttons["Center note 1"].tap()
        app.buttons["Center note 2"].tap()
        XCTAssertEqual(cell(1, 3).label, "Row 1, column 3, centered notes 1 2")

        // Grid notes elsewhere stay in the grid.
        cell(1, 4).tap()
        app.buttons["Notes"].tap()
        app.buttons["Note 6"].tap()
        XCTAssertEqual(cell(1, 4).label, "Row 1, column 4, notes 6")
        XCTAssertEqual(cell(1, 3).label, "Row 1, column 3, centered notes 1 2")

        // Adding a grid note to the centered cell switches it to the grid; undo switches it back.
        cell(1, 3).tap()
        app.buttons["Note 4"].tap()
        XCTAssertEqual(cell(1, 3).label, "Row 1, column 3, notes 1 2 4")
        app.buttons["Undo"].tap()
        XCTAssertEqual(cell(1, 3).label, "Row 1, column 3, centered notes 1 2")

        // With a cell selected, the mode buttons restyle its notes (undoably).
        cell(1, 4).tap()
        app.buttons["Center"].tap()
        XCTAssertEqual(cell(1, 4).label, "Row 1, column 4, centered notes 6", "Center restyles the selected cell")
        app.buttons["Notes"].tap()
        XCTAssertEqual(cell(1, 4).label, "Row 1, column 4, notes 6", "Notes restyles it back")
        app.buttons["Undo"].tap()
        XCTAssertEqual(cell(1, 4).label, "Row 1, column 4, centered notes 6")

        app.buttons["Center"].tap()
        Thread.sleep(forTimeInterval: 0.5) // let the key's highlight settle for the screenshot
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "center notes"; shot.lifetime = .keepAlways
        add(shot)
    }
}
