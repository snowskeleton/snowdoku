import XCTest

/// New games come from the bundled puzzle bank, so they open at once, Extreme included.
final class PuzzleBankTests: XCTestCase {
    func testExtremeIsOfferedAndStartsFromTheBank() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.staticTexts["Free Play"].waitForExistence(timeout: 10))
        app.staticTexts["Free Play"].tap()

        let extreme = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Extreme")).firstMatch
        app.scroll(to: extreme).tap()

        // On-device generation can't make Extreme at all, so a board here means the bank served it.
        let cell = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Row 1, column 1,")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 5), "an Extreme game should open on the board")
    }
}
