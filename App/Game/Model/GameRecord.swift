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
    /// Cells whose notes are drawn centered (missing in saves from before centered notes).
    var centeredNotes: CellSet?
    var elapsed: Double
    var mistakes: Int
    var hintsUsed: Int
    var difficulty: Difficulty
    var hardest: Technique
    var techniques: [Technique]
    var dailyKey: String?
    var practice: Technique?
    var completed: Bool
    var drill: Drill?
    var drillState: DrillState?
}
