import SwiftUI
import SudokuCore

extension Highlight.Role {
    var color: Color {
        switch self {
        case .pattern: .yellow
        case .secondary: .orange
        case .fin: .purple
        case .colorA: .blue
        case .colorB: .green
        case .colorC: .pink
        case .colorD: .teal
        case .chainOn: .green
        case .chainOff: .blue
        }
    }
}
