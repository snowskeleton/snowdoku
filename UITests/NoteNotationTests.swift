import XCTest

/// Settings → Note style. Auto centers a cell's notes while it has three or fewer and uses the grid
/// from four; it covers the notes pad and Fill. Manual (the default) always uses the grid.
final class NoteNotationTests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() { continueAfterFailure = false }

    func launch(_ notation: String) {
        app = XCUIApplication()
        app.launchArguments = ["-puzzle", BoardInputTests.puzzle, "-noteNotation", notation]
        app.launch()
        XCTAssertTrue(app.buttons["Note 1"].waitForExistence(timeout: 10))
    }

    func cell(_ r: Int, _ c: Int) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label BEGINSWITH %@", "Row \(r), column \(c),"))
            .firstMatch
    }

    func testAutoCentersUpToThreeNotes() {
        launch("auto")
        cell(1, 3).tap()
        app.buttons["Note 1"].tap()
        app.buttons["Note 2"].tap()
        app.buttons["Note 4"].tap()
        XCTAssertEqual(cell(1, 3).label, "Row 1, column 3, centered notes 1 2 4")
        app.buttons["Note 6"].tap()
        XCTAssertEqual(cell(1, 3).label, "Row 1, column 3, notes 1 2 4 6", "four notes switch to the grid")
        app.buttons["Note 6"].tap()
        XCTAssertEqual(cell(1, 3).label, "Row 1, column 3, centered notes 1 2 4", "and back when one goes")
    }

    func testAutoFill() {
        launch("auto")
        app.buttons["Fill"].tap()
        // r1c3 can be 1 2 4; r3c1 can be 1 2.
        XCTAssertEqual(cell(1, 3).label, "Row 1, column 3, centered notes 1 2 4")
        XCTAssertEqual(cell(3, 1).label, "Row 3, column 1, centered notes 1 2")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "auto fill"; shot.lifetime = .keepAlways
        add(shot)
    }

    func testManualUsesTheGrid() {
        launch("manual")
        app.buttons["Fill"].tap()
        XCTAssertEqual(cell(1, 3).label, "Row 1, column 3, notes 1 2 4")
    }
}
