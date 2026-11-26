import XCTest

/// In wide space the board sits beside the pads, and the controls stay above the pads
/// (not in the toolbar), as in tall space.
final class WideLayoutTests: XCTestCase {
    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    func testControlsStayAbovePadsWhenWide() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPhone is portrait-only")
        XCUIDevice.shared.orientation = .landscapeLeft
        let app = XCUIApplication()
        app.launchArguments = ["-puzzle", BoardInputTests.puzzle]
        app.launch()

        let hint = app.buttons["Hint"]
        XCTAssertTrue(hint.waitForExistence(timeout: 10))
        XCTAssertFalse(app.navigationBars.buttons["Hint"].exists, "controls are not in the toolbar")
        let pad = app.buttons.matching(NSPredicate(format: "label BEGINSWITH '1,'")).firstMatch
        XCTAssertLessThan(hint.frame.maxY, pad.frame.minY, "controls sit above the pads")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "wide"; shot.lifetime = .keepAlways
        add(shot)
    }
}
