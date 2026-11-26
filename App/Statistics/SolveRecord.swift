import Foundation
import SudokuCore

/// One finished game, kept so the statistics can chart progress over time.
struct SolveRecord: Codable, Equatable, Identifiable {
    var id: UUID
    var date: Date
    var difficulty: Difficulty
    var seconds: Double
    var mistakes: Int
    var hintsUsed: Int
    /// The hardest technique the puzzle needs.
    var hardest: Technique
    var daily: Bool
}
