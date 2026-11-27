import Foundation
import SudokuCore

/// What a finished game (or found drill) tells us about how hard its techniques are, queued in
/// `ReportQueue` for a future server that grades difficulty from everyone's solves. Anonymous: the
/// install ID is random, and nothing identifies the player.
struct SolveReport: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case random, daily, practice, drill }

    /// Bump when the fields change, so the server can read old reports.
    static let schema = 1

    var schema = SolveReport.schema
    /// The game's ID, so a report uploaded twice is counted once.
    var id: UUID
    var installID: UUID
    var appVersion: String
    var platform: String
    /// UTC day the game was finished (`DailySchedule.key`); no time of day.
    var day: String
    var kind: Kind
    /// The givens as played (bank puzzles are served transformed; ratings are transform-invariant).
    var puzzle: String
    /// A drill's starting position, givens and filled cells.
    var start: String?
    var difficulty: Difficulty
    var hardest: Technique
    var drillTechnique: Technique?
    var seconds: Double
    var mistakes: Int
    var hintsUsed: Int
    var moves: [TechniqueMove]
}

extension SolveReport {
    @MainActor
    init(_ g: Game, moves: [TechniqueMove], installID: UUID) {
        let kind: Kind = g.drill != nil ? .drill : g.dailyKey != nil ? .daily : g.practice != nil ? .practice : .random
        self.init(id: g.id, installID: installID,
                  appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?",
                  platform: Self.platform, day: DailySchedule.key(), kind: kind, puzzle: g.puzzle.string,
                  start: g.drill?.values.string, difficulty: g.difficulty, hardest: g.hardest,
                  drillTechnique: g.drill?.technique, seconds: g.elapsed(), mistakes: g.mistakes,
                  hintsUsed: g.hintsUsed, moves: moves)
    }

    private static var platform: String {
        #if os(macOS)
        "macOS"
        #else
        "iOS"
        #endif
    }
}
