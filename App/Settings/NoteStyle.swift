import Foundation

/// Where a cell's notes are drawn.
enum NoteStyle: String, CaseIterable, Identifiable {
    /// Each digit in its own spot of a 3x3 grid (1 top left … 9 bottom right).
    case grid
    /// The digits side by side in the middle of the cell.
    case center
    var id: String { rawValue }
    var label: String {
        switch self {
        case .grid: "In a 3×3 grid"
        case .center: "Centered"
        }
    }
}
