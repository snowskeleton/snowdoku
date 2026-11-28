import Foundation
import SudokuCore

/// Puzzles bundled with the app (`Resources/Puzzles.tsv`, mined with `sudokugen bank`), already
/// rated, so new games start instantly and Extreme is playable.
enum PuzzleBank {
    /// Puzzles by tier, in file order (dailies index into it). Loaded on first use.
    static let all: [Difficulty: [BankedPuzzle]] = {
        guard let url = Bundle.main.url(forResource: "Puzzles", withExtension: "tsv"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return [:] }
        return Dictionary(grouping: BankedPuzzle.parse(text), by: \.difficulty)
    }()

    static func hasPuzzles(_ d: Difficulty) -> Bool { all[d]?.isEmpty == false }

    /// A random puzzle of the tier, randomly transformed.
    static func random(_ d: Difficulty) -> GeneratedPuzzle? {
        var rng = SystemRandomNumberGenerator()
        return all[d]?.randomElement(using: &rng)?.generated(.random(using: &rng))
    }

    /// The daily puzzle for a `DailySchedule` day: the same for everyone, whatever the engine does.
    static func daily(_ d: Difficulty, seed: UInt64) -> GeneratedPuzzle? {
        Daily.pick(from: all[d] ?? [], difficulty: d, seed: seed)
    }
}
