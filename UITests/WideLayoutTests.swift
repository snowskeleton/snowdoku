import XCTest

/// In wide space the controls move into the toolbar; in tall space they sit above the pads.
final class WideLayoutTests: XCTestCase {
    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
    }

    func testControlsMoveToToolbarWhenWide() throws {
        try XCTSkipUnless(UIDevice.current.userInterfaceIdiom == .pad, "iPhone is portrait-only")
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = ["-puzzle", BoardInputTests.puzzle]
        app.launch()

        let toolbarHint = app.navigationBars.buttons["Hint"]
        XCTAssertTrue(app.buttons["Hint"].waitForExistence(timeout: 10))
        XCTAssertFalse(toolbarHint.exists, "tall layout keeps controls above the pads")

        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertTrue(toolbarHint.waitForExistence(timeout: 5), "wide layout puts controls in the toolbar")
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "wide"; shot.lifetime = .keepAlways
        add(shot)
    }
}
