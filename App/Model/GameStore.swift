import Foundation
import Observation
import SudokuCore

struct Stats: Codable {
    var started: [Difficulty: Int] = [:]
    var completed: [Difficulty: Int] = [:]
    var bestTime: [Difficulty: Double] = [:]
    var totalTime: [Difficulty: Double] = [:]
    var dailyCompleted: Set<String> = []
    var streak = 0
    var lastDaily: String?
}

/// Owns the current game, puzzle creation, persistence and statistics.
@Observable @MainActor
final class GameStore {
    var game: Game?
    var isPlaying = false
    var generating: String?
    var stats = Stats()
    var errorMessage: String?

    /// Levels offered for random games. Extreme puzzles are too rare to mine on-device;
    /// they'll come from the bundled bank.
    static let playable: [Difficulty] = [.beginner, .easy, .medium, .hard, .expert, .master]

    private let defaults = UserDefaults.standard

    init() {
        if let data = defaults.data(forKey: "currentGame"), let r = try? JSONDecoder().decode(GameRecord.self, from: data), !r.completed {
            game = Game(record: r)
            game?.pauseClock()
        }
        if let data = defaults.data(forKey: "stats"), let s = try? JSONDecoder().decode(Stats.self, from: data) {
            stats = s
        }
    }

    var hasGameInProgress: Bool { game.map { !$0.isComplete } ?? false }

    func save() {
        if let g = game, let data = try? JSONEncoder().encode(g.record) {
            defaults.set(data, forKey: "currentGame")
        }
        if let data = try? JSONEncoder().encode(stats) { defaults.set(data, forKey: "stats") }
    }

    func resume() {
        guard game != nil else { return }
        game?.resumeClock()
        isPlaying = true
    }

    func leaveGame() {
        game?.pauseClock()
        isPlaying = false
        save()
    }

    private func start(_ p: GeneratedPuzzle, dailyKey: String? = nil, practice: Technique? = nil) {
        game = Game(p, dailyKey: dailyKey, practice: practice)
        stats.started[p.rating.difficulty, default: 0] += 1
        isPlaying = true
        save()
    }

    func newGame(_ difficulty: Difficulty) async {
        generating = "Building a \(difficulty.name.lowercased()) puzzle…"
        defer { generating = nil }
        let p = await Task.detached(priority: .userInitiated) { () -> GeneratedPuzzle? in
            var rng = SystemRandomNumberGenerator()
            return Generator.generate(difficulty: difficulty, maxAttempts: 4000, using: &rng)
        }.value
        guard let p else { errorMessage = "Couldn't build a \(difficulty.name) puzzle. Try again."; return }
        start(p)
    }

    /// A puzzle that requires a specific technique, for practice from the technique library.
    func practice(_ technique: Technique) async {
        generating = "Finding a puzzle that needs \(technique.name)…"
        defer { generating = nil }
        let p = await Task.detached(priority: .userInitiated) { () -> GeneratedPuzzle? in
            var rng = SystemRandomNumberGenerator()
            return Generator.generate(requiring: technique, maxAttempts: 3000, using: &rng)
        }.value
        guard let p else { errorMessage = "\(technique.name) is rare. No puzzle found this time; try again."; return }
        start(p, practice: technique)
    }

    // MARK: Daily

    static func dayKey(_ date: Date = Date()) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    /// Daily difficulty ramps through the week: Monday easy … Sunday master.
    static func dailyDifficulty(_ date: Date = Date()) -> Difficulty {
        let weekday = Calendar(identifier: .gregorian).component(.weekday, from: date) // 1 = Sunday
        return [.master, .easy, .easy, .medium, .hard, .hard, .expert][weekday - 1]
    }

    var dailyDone: Bool { stats.dailyCompleted.contains(Self.dayKey()) }

    func daily() async {
        let key = Self.dayKey()
        if let g = game, g.dailyKey == key, !g.isComplete { resume(); return }
        let difficulty = Self.dailyDifficulty()
        let c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        let seed = Daily.seed(year: c.year!, month: c.month!, day: c.day!)
        generating = "Preparing today's puzzle…"
        defer { generating = nil }
        let p = await Task.detached(priority: .userInitiated) { () -> GeneratedPuzzle? in
            var rng = SplitMix64(seed: seed)
            return Generator.generate(difficulty: difficulty, maxAttempts: 4000, using: &rng)
        }.value
        guard let p else { errorMessage = "Couldn't prepare today's puzzle."; return }
        start(p, dailyKey: key)
    }

    // MARK: Completion

    func recordCompletion(_ g: Game) {
        let d = g.difficulty
        let t = g.elapsed()
        stats.completed[d, default: 0] += 1
        stats.totalTime[d, default: 0] += t
        if g.hintsUsed == 0 { stats.bestTime[d] = min(stats.bestTime[d] ?? .infinity, t) }
        if let key = g.dailyKey, !stats.dailyCompleted.contains(key) {
            stats.dailyCompleted.insert(key)
            let yesterday = Self.dayKey(Calendar.current.date(byAdding: .day, value: -1, to: Date())!)
            stats.streak = stats.lastDaily == yesterday ? stats.streak + 1 : 1
            stats.lastDaily = key
        }
        save()
    }
}
