import Foundation
import Observation
import SudokuCore

/// A digit chosen on a pad with no cell selected; tapping cells then applies it.
struct ArmedDigit: Equatable {
    var digit: Int
    var small: Bool
    /// A centered note (one-pad Center mode) rather than a grid note.
    var centered = false
}
