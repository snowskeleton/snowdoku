import Foundation

/// How the digit pads are laid out.
enum PadLayout: String, CaseIterable, Identifiable {
    /// A pad for values and a pad for notes, side by side.
    case twoPads
    /// One pad, with a Digits / Notes switch choosing what it enters.
    case onePad
    var id: String { rawValue }
    var label: String {
        switch self {
        case .twoPads: "Two pads"
        case .onePad: "One pad with a Notes switch"
        }
    }
}
