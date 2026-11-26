import Foundation

/// The notation for notes that don't come from the one-pad Notes / Center keys: the two-pad notes
/// pad, Shift (keyboard and click) and Fill.
enum NoteNotation: String, CaseIterable, Identifiable {
    /// Always the 3x3 grid; centered notes only from the Center key.
    case manual
    /// Centered for up to three notes, the grid from four, changing as notes come and go.
    case auto
    var id: String { rawValue }
    var label: String {
        switch self {
        case .manual: "Manual"
        case .auto: "Auto"
        }
    }
    var kind: NoteKind { self == .auto ? .auto : .grid }
}
