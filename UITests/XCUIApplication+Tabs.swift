import XCTest

extension XCUIApplication {
    /// A root tab's button. On iPhone it sits in the bottom tab bar; on a large iPad,
    /// `.sidebarAdaptable` floats the tabs at the top, outside any `TabBar` element, so
    /// `tabBars` finds nothing there. Both usually expose the tab's icon as its identifier, but
    /// after some saved state the bottom bar's buttons come without one, so a button with the tab's
    /// name and no identifier matches too.
    func tab(_ name: String) -> XCUIElement {
        let icons = ["Play": "square.grid.3x3", "Techniques": "book", "Statistics": "chart.bar", "Settings": "gear"]
        return buttons.matching(NSPredicate(format: "label == %@ AND (identifier == %@ OR identifier == '')", name, icons[name]!)).firstMatch
    }
}
