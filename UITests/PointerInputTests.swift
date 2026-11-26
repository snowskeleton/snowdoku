import XCTest

/// iPad pointer shortcuts with a digit armed: Shift-click enters it as a note, right-click removes that note.
final class PointerInputTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "pointer shortcuts are for iPad and Mac")
        continueAfterFailure = false
    }

    func launch(_ extra: [String] = []) {
        app = XCUIApplication()
        app.launchArguments = ["-puzzle", BoardInputTests.puzzle] + extra
        app.launch()
        XCTAssertTrue(bigDigit(4).waitForExistence(timeout: 10))
    }

    func cell(_ r: Int, _ c: Int) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Row \(r), column \(c),"))
            .firstMatch
    }

    func bigDigit(_ d: Int) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(d),")).firstMatch
    }

    func shiftClick(_ e: XCUIElement) {
        XCUIElement.perform(withKeyModifiers: .shift) { e.click() }
    }

    func testShiftClickEntersANoteWithTheBigDigitArmed() {
        launch()
        bigDigit(4).tap()
        shiftClick(cell(1, 3))
        XCTAssertEqual(cell(1, 3).label, "Row 1, column 3, notes 4")
        shiftClick(cell(1, 3))
        XCTAssertEqual(cell(1, 3).label, "Row 1, column 3, empty", "Shift-click again toggles the note off")
        // A plain click still places the big digit.
        cell(1, 3).click()
        XCTAssertEqual(cell(1, 3).label, "Row 1, column 3, 4")
    }

    func testShiftClickFollowsAutoNotation() {
        launch(["-noteNotation", "auto"])
        bigDigit(4).tap()
        shiftClick(cell(1, 3))
        XCTAssertEqual(cell(1, 3).label, "Row 1, column 3, centered notes 4")
    }

    func testRightClickRemovesOnlyTheArmedNote() {
        launch()
        app.buttons["Note 4"].tap()
        cell(1, 3).click()
        app.buttons["Note 6"].tap()
        cell(1, 3).click()
        XCTAssertEqual(cell(1, 3).label, "Row 1, column 3, notes 4 6")
        cell(1, 3).rightClick()
        XCTAssertEqual(cell(1, 3).label, "Row 1, column 3, notes 4")
        cell(1, 3).rightClick()
        XCTAssertEqual(cell(1, 3).label, "Row 1, column 3, notes 4", "right-click never adds a note")
        // Works with the big digit armed too.
        bigDigit(4).tap()
        cell(1, 3).rightClick()
        XCTAssertEqual(cell(1, 3).label, "Row 1, column 3, empty")
    }

    func testBothCanBeTurnedOff() {
        launch(["-shiftClickNotes", "NO", "-rightClickRemovesNote", "NO"])
        app.buttons["Note 4"].tap()
        cell(1, 3).click()
        cell(1, 3).rightClick()
        XCTAssertEqual(cell(1, 3).label, "Row 1, column 3, notes 4", "right-click does nothing when off")
        bigDigit(4).tap()
        shiftClick(cell(1, 3))
        XCTAssertEqual(cell(1, 3).label, "Row 1, column 3, 4", "Shift-click is a plain click when off")
    }
}
