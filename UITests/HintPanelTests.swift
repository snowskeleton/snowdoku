import XCTest

/// The hint panel floats over the controls row (and the board above it), never over the pads.
final class HintPanelTests: XCTestCase {
    override func setUp() { continueAfterFailure = false }
    override func tearDown() { XCUIDevice.shared.orientation = .portrait }

    func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-puzzle", BoardInputTests.puzzle] + extra
        app.launch()
        XCTAssertTrue(app.buttons["Hint"].firstMatch.waitForExistence(timeout: 10))
        return app
    }

    func assertPadsUncovered(_ app: XCUIApplication, notes: Bool, file: StaticString = #filePath, line: UInt = #line) {
        let more = app.buttons["Show more"]
        XCTAssertTrue(more.waitForExistence(timeout: 5), "hint panel is open", file: file, line: line)
        for d in 1...9 {
            let big = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "\(d),")).firstMatch
            XCTAssertTrue(big.isHittable, "digit \(d) stays tappable under the hint panel", file: file, line: line)
            XCTAssertFalse(big.frame.intersects(more.frame), "Show more doesn't sit on digit \(d)", file: file, line: line)
            if notes {
                XCTAssertTrue(app.buttons["Note \(d)"].isHittable, "note \(d) stays tappable", file: file, line: line)
            }
        }
    }

    func testHintPanelLeavesTwoPadsTappable() {
        let app = launch()
        app.buttons["Hint"].firstMatch.tap()
        assertPadsUncovered(app, notes: true)
        // Grows upward as the hint gets longer, still clear of the pads.
        app.buttons["Show more"].tap()
        app.buttons["Show more"].tap()
        assertPadsUncovered(app, notes: true)
    }

    func testHintPanelLeavesOnePadTappable() {
        let app = launch(["-padLayout", "onePad"])
        app.buttons["Hint"].firstMatch.tap()
        assertPadsUncovered(app, notes: false)
        XCTAssertTrue(app.buttons["Undo"].isHittable, "the one pad's own keys stay tappable")
    }

    func testHintPanelLeavesPadsTappableWhenWide() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPhone is portrait-only")
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = launch()
        app.buttons["Hint"].firstMatch.tap()
        assertPadsUncovered(app, notes: true)
    }
}
