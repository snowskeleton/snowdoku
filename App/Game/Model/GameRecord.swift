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
    /// Cells whose notes are centered or gridded by count (Auto notation).
    var autoNotes: CellSet?
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
    /// Moves so far and the technique each needed (missing in older saves).
    var moves: [TechniqueMove]?
    /// The campaign level or drill round this game belongs to.
    var campaign: CampaignContext?
    /// A singles drill's or lesson's question.
    var spotlight: Spotlight?
    /// The opening run of one digit (missing in older saves).
    var firstRun: FirstDigitRun?
}
