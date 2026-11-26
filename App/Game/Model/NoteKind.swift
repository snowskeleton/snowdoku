import Foundation

/// How a cell draws its notes. Set by the note last added to the cell.
enum NoteKind: Equatable {
    /// Each digit in its spot of the cell's 3x3 grid.
    case grid
    /// The digits side by side in the middle.
    case center
    /// Centered while there are three or fewer, in the grid from four (Settings → Auto).
    case auto
}
