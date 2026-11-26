import Foundation

/// What the one-pad layout's digits enter.
enum PadMode: CaseIterable {
    /// Values.
    case digits
    /// Notes drawn in the cell's 3x3 grid.
    case notes
    /// Notes drawn centered in the cell.
    case centerNotes

    var next: PadMode {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}
