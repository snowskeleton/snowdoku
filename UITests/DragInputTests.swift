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

    func testDraggingWithNothingArmedChangesNothing() {
        drag(cell(1, 3), cell(1, 7))
        for c in [3, 4, 6, 7] { XCTAssertEqual(cell(1, c).label, "Row 1, column \(c), empty") }
    }
}
