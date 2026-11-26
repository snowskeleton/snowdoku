import Foundation
import Observation
import SudokuCore

/// A digit chosen on a pad with no cell selected; tapping cells then applies it.
struct ArmedDigit: Equatable {
    var digit: Int
    var small: Bool
    /// For a small digit: how the notes it adds are drawn.
    var kind = NoteKind.grid
}
