import XCTest

/// Drives the real app: cell selection, deselection, and digit-first entry.
final class BoardInputTests: XCTestCase {
    // Row 1 is 5 3 . . 7 . . . .
    static let puzzle = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"

    var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-puzzle", Self.puzzle]
        app.launch()
    }

    func cell(_ r: Int, _ c: Int) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Row \(r), column \(c),"))
            .firstMatch
    }

    func bigDigit(_ d: Int) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(d),")).firstMatch
    }

    func testSelectAnyCellAndDeselect() {
        let empty = cell(1, 3)
        XCTAssertTrue(empty.waitForExistence(timeout: 10))
        empty.tap()
        XCTAssertTrue(empty.isSelected, "empty cell should be selectable")

        let far = cell(9, 1) // empty, unhighlighted relative to r1c3
        far.tap()
        XCTAssertTrue(far.isSelected, "unhighlighted cell should be selectable")
        XCTAssertFalse(empty.isSelected)

        far.tap()
        XCTAssertFalse(far.isSelected, "tapping the selected cell deselects it")
    }

    func testDigitFirstEntry() {
        XCTAssertTrue(cell(1, 3).waitForExistence(timeout: 10))
        bigDigit(4).tap()
        XCTAssertTrue(bigDigit(4).isSelected, "digit should be armed")

        cell(1, 3).tap()
        XCTAssertEqual(cell(1, 3).label, "Row 1, column 3, 4")
        cell(1, 4).tap()
        XCTAssertEqual(cell(1, 4).label, "Row 1, column 4, 4")
        cell(9, 9).tap() // a given: unchanged
        XCTAssertEqual(cell(9, 9).label, "Row 9, column 9, 9, given")

        bigDigit(4).tap()
        XCTAssertFalse(bigDigit(4).isSelected, "tapping the armed digit disarms it")
    }

    func testCellFirstEntryThenDigitFirst() {
        XCTAssertTrue(cell(1, 3).waitForExistence(timeout: 10))
        cell(1, 3).tap()
        bigDigit(4).tap()
        XCTAssertEqual(cell(1, 3).label, "Row 1, column 3, 4")
        // Selection is consumed, so the next digit arms and applies to tapped cells.
        bigDigit(6).tap()
        cell(1, 4).tap()
        XCTAssertEqual(cell(1, 4).label, "Row 1, column 4, 6")
    }
}
