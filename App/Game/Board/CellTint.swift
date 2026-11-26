import SwiftUI

/// How strongly the board's highlight tints are drawn. A translucent tint reads much weaker
/// over a black background than over white, so dark mode gets stronger levels, and
/// Increase Contrast pushes both further.
struct CellTint {
    let colorScheme: ColorScheme
    let contrast: ColorSchemeContrast

    /// The selected cell's fill (it also gets an accent border).
    var selected: Double { level(light: 0.42, dark: 0.62) }
    /// A cell holding the highlighted digit.
    var sameDigit: Double { level(light: 0.30, dark: 0.45) }
    /// An empty cell whose notes contain the highlighted digit.
    var noteDigit: Double { level(light: 0.17, dark: 0.28) }
    /// The selected cell's row, column and box.
    var peer: Double { level(light: 0.10, dark: 0.20) }
    /// Hint colors (wrong, placement, pattern cell) and the hint's houses.
    var hint: Double { level(light: 0.35, dark: 0.45) }
    var hintHouse: Double { level(light: 0.16, dark: 0.24) }
    var conflict: Double { level(light: 0.18, dark: 0.28) }

    private func level(light: Double, dark: Double) -> Double {
        let base = colorScheme == .dark ? dark : light
        return contrast == .increased ? min(base * 1.4, 0.85) : base
    }
}
