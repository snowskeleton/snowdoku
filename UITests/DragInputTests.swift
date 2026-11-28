import XCTest

/// With a digit armed, dragging across cells applies it to each one. The first cell decides whether
/// the stroke adds or removes, and the whole stroke is one undo step.
final class DragInputTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // Row 1 is 5 3 . . 7 . . . .
        app.launchArguments = ["-puzzle", BoardInputTests.puzzle]
        app.launch()
        XCTAssertTrue(cell(1, 3).waitForExistence(timeout: 10))
    }

    func cell(_ r: Int, _ c: Int) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Row \(r), column \(c),"))
            .firstMatch
    }

    func bigDigit(_ d: Int) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(d),")).firstMatch
    }

    func drag(_ from: XCUIElement, _ to: XCUIElement) {
        from.press(forDuration: 0.1, thenDragTo: to)
    }

    /// A quick stroke from near the edge of a cell, the way a finger moves: by the time the pan is
    /// recognized, the touch is already in the next cell.
    func flick(_ from: XCUIElement, _ to: XCUIElement) {
        let dy: CGFloat = from.frame.midY < to.frame.midY ? 0.9 : 0.1
        from.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: dy))
            .press(forDuration: 0, thenDragTo: to.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)),
                   withVelocity: 2000, thenHoldForDuration: 0.05)
    }

    func testDraggingAddsThenRemovesNotes() {
        app.buttons["Note 4"].tap()
        drag(cell(1, 3), cell(1, 7))
        for c in [3, 4, 6, 7] {
            XCTAssertEqual(cell(1, c).label, "Row 1, column \(c), notes 4", "the stroke adds 4 to column \(c)")
        }
        XCTAssertEqual(cell(1, 5).label, "Row 1, column 5, 7, given", "givens are skipped")
        XCTAssertEqual(cell(1, 8).label, "Row 1, column 8, empty", "the stroke stops where the drag does")

        // Starting on a cell that has the note removes it along the way, and never adds.
        drag(cell(1, 4), cell(1, 8))
        XCTAssertEqual(cell(1, 3).label, "Row 1, column 3, notes 4")
        for c in [4, 6, 7, 8] {
            XCTAssertEqual(cell(1, c).label, "Row 1, column \(c), empty", "the stroke removes 4 from column \(c)")
        }

        // Each stroke is one undo step.
        app.buttons["Undo"].tap()
        for c in [3, 4, 6, 7] { XCTAssertEqual(cell(1, c).label, "Row 1, column \(c), notes 4") }
        app.buttons["Undo"].tap()
        for c in [3, 4, 6, 7] { XCTAssertEqual(cell(1, c).label, "Row 1, column \(c), empty") }
    }

    func testDraggingPlacesTheArmedBigDigitInEmptyCells() {
        bigDigit(4).tap()
        drag(cell(1, 3), cell(1, 4))
        XCTAssertEqual(cell(1, 3).label, "Row 1, column 3, 4, mistake", "two 4s in one row conflict")
        XCTAssertEqual(cell(1, 4).label, "Row 1, column 4, 4, mistake")
    }

    func testDraggingWithNothingArmedSelectsCellsForThePads() {
        drag(cell(1, 3), cell(1, 7))
        for c in 3...7 { XCTAssertTrue(cell(1, c).isSelected, "column \(c) is selected") }
        XCTAssertFalse(cell(1, 8).isSelected)

        // A note goes into every empty selected cell, and the selection stays.
        app.buttons["Note 4"].tap()
        for c in [3, 4, 6, 7] { XCTAssertEqual(cell(1, c).label, "Row 1, column \(c), notes 4") }
        XCTAssertEqual(cell(1, 5).label, "Row 1, column 5, 7, given")
        XCTAssertTrue(cell(1, 7).isSelected)

        // Once every cell has it, the same note comes out of all of them.
        app.buttons["Note 4"].tap()
        for c in [3, 4, 6, 7] { XCTAssertEqual(cell(1, c).label, "Row 1, column \(c), empty") }

        // Each pad tap is one undo step.
        app.buttons["Undo"].tap()
        for c in [3, 4, 6, 7] { XCTAssertEqual(cell(1, c).label, "Row 1, column \(c), notes 4") }

        // Tapping one selected cell selects just it.
        cell(1, 4).tap()
        XCTAssertTrue(cell(1, 4).isSelected)
        XCTAssertFalse(cell(1, 3).isSelected)
        XCTAssertFalse(cell(1, 6).isSelected)
    }

    /// A stroke may start on a cell above a given and run down through it, as well as the other way.
    func testDraggingDownThroughAGivenRemovesNotes() {
        // Column 3 is . . 8 . from the top.
        app.buttons["Note 4"].tap()
        for r in [1, 2, 4] { cell(r, 3).tap() }
        for r in [1, 2, 4] { XCTAssertEqual(cell(r, 3).label, "Row \(r), column 3, notes 4") }

        flick(cell(2, 3), cell(4, 3))
        XCTAssertEqual(cell(2, 3).label, "Row 2, column 3, empty", "the stroke starts by removing 4")
        XCTAssertEqual(cell(4, 3).label, "Row 4, column 3, empty", "and keeps removing past the given")
        XCTAssertEqual(cell(1, 3).label, "Row 1, column 3, notes 4")

        // Back up the other way.
        for r in [2, 4] { cell(r, 3).tap() }
        flick(cell(4, 3), cell(2, 3))
        XCTAssertEqual(cell(4, 3).label, "Row 4, column 3, empty")
        XCTAssertEqual(cell(2, 3).label, "Row 2, column 3, empty")
    }

    func testABigDigitFillsTheSelectionThenClearsIt() {
        drag(cell(2, 2), cell(2, 3))
        XCTAssertTrue(cell(2, 2).isSelected)
        XCTAssertTrue(cell(2, 3).isSelected)
        bigDigit(2).tap()
        XCTAssertEqual(cell(2, 2).label, "Row 2, column 2, 2, mistake")
        XCTAssertEqual(cell(2, 3).label, "Row 2, column 3, 2, mistake")
        XCTAssertFalse(cell(2, 2).isSelected, "a big digit ends the selection, as with one cell")
        XCTAssertFalse(cell(2, 3).isSelected)
    }
}
