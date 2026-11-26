import Foundation
import Observation
import SudokuCore

/// How (and whether) the player is told about mistakes.
enum MistakeMode: String, CaseIterable, Identifiable {
    case off, conflicts, solution
    var id: String { rawValue }
    var label: String {
        switch self {
        case .off: "Off"
        case .conflicts: "Rule conflicts"
        case .solution: "Check against solution"
        }
    }
}
