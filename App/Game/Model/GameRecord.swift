import Foundation
import Observation
import SudokuCore

/// Persisted form of a game.
struct GameRecord: Codable {
    var id: UUID
    var puzzle: Grid
    var solution: Grid
    var values: [UInt8]
    var notes: [UInt16]
    var elapsed: Double
    var mistakes: Int
    var hintsUsed: Int
    var difficulty: Difficulty
    var hardest: Technique
    var techniques: [Technique]
    var dailyKey: String?
    var practice: Technique?
    var completed: Bool
}
