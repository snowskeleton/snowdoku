import Foundation
import SudokuCore

/// One step of progress in a game: the player placed a correct digit (or, in a drill, made the
/// drill's move), and `technique` is the hardest one the solver needed to get there from the
/// board as it stood (`HumanSolver.nextPlacementBottleneck`). These feed the per-technique skill
/// statistics and the solve reports queued for crowd-sourced difficulty grading.
struct TechniqueMove: Codable, Equatable, Sendable {
    var technique: Technique
    /// Game time since the previous move (paused time excluded).
    var seconds: Double
    /// Game time when the move was made.
    var at: Double
    /// Wrong digits entered while working on this move.
    var mistakes: Int
    /// The furthest hint level shown for this move (`HintLevel` raw value), nil if none.
    var hintLevel: Int?
    /// The hint's Apply button made the move.
    var applied: Bool

    /// Made with no hint and no wrong digit along the way.
    var unaided: Bool { mistakes == 0 && hintLevel == nil && !applied }
}
