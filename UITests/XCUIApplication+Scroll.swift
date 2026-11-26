import XCTest

extension XCUIApplication {
    /// Swipes up until `element` is on screen (lists load rows lazily, so it may not exist yet).
    @discardableResult
    func scroll(to element: XCUIElement, maxSwipes: Int = 12) -> XCUIElement {
        var n = 0
        while !(element.exists && element.isHittable) && n < maxSwipes {
            swipeUp(velocity: .slow)
            n += 1
        }
        return element
    }
}
