import XCTest

/// The one-pad layout: a single set of digits with a Digits / Notes switch.
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
}
