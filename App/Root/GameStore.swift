import Foundation
import Observation
import SudokuCore

/// One window's game: the current puzzle, puzzle creation and its persistence.
/// Each window owns its own store, so two iPad or Mac windows can play different games.
/// Statistics are app-wide and live in `StatsStore`.
@Observable @MainActor
final class GameStore {
    var game: Game?
    var isPlaying = false
    var generating: String?
    var errorMessage: String?

    /// Levels offered for random games. Extreme puzzles are too rare to mine on-device;
    /// they'll come from the bundled bank.
    static let playable: [Difficulty] = [.beginner, .easy, .medium, .hard, .expert, .master]

    private let stats: StatsStore
    private let defaults = UserDefaults.standard

    /// Restores the last unfinished game. (Two windows opened on the same saved game play
    /// separate copies; whichever saves last is what Continue offers next time.)
    init(stats: StatsStore) {
        self.stats = stats
        if let data = defaults.data(forKey: "currentGame"), let r = try? JSONDecoder().decode(GameRecord.self, from: data), !r.completed {
            game = Game(record: r)
            game?.pauseClock()
        }
    }

    var hasGameInProgress: Bool { game.map { !$0.isComplete } ?? false }

    func save() {
        if let g = game, let data = try? JSONEncoder().encode(g.record) {
            defaults.set(data, forKey: "currentGame")
        }
    }

    func resume() {
        guard game != nil else { return }
        game?.resumeClock()
        isPlaying = true
    }

    /// Called when the board is dismissed, by the Home button or the navigation back button.
    func leaveGame() {
        game?.pauseClock()
        isPlaying = false
        save()
    }

    func recordCompletion(_ g: Game) {
        stats.recordCompletion(g)
        save()
    }

    private func start(_ p: GeneratedPuzzle, dailyKey: String? = nil, practice: Technique? = nil) {
        game = Game(p, dailyKey: dailyKey, practice: practice)
        stats.recordStart(p.rating.difficulty)
        isPlaying = true
        save()
    }

    /// Starts a specific puzzle (used by debug/test launch arguments; later by puzzle import).
    func start(puzzle: Grid) {
        guard case .unique(let solution) = BruteForce.analyze(puzzle) else { errorMessage = "That puzzle doesn't have a unique solution."; return }
        start(GeneratedPuzzle(puzzle: puzzle, solution: solution, rating: Rater.rate(puzzle, solution: solution)))
    }

    func newGame(_ difficulty: Difficulty) async {
        generating = "Building a \(difficulty.name.lowercased()) puzzle…"
        defer { generating = nil }
        // Generation is CPU-heavy; keep it off the main actor.
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

    func daily() async {
        let key = DailySchedule.key()
        if let g = game, g.dailyKey == key, !g.isComplete { resume(); return }
        let difficulty = DailySchedule.difficulty()
        let seed = DailySchedule.seed()
        generating = "Preparing today's puzzle…"
        defer { generating = nil }
        let p = await Task.detached(priority: .userInitiated) { () -> GeneratedPuzzle? in
            var rng = SplitMix64(seed: seed)
            return Generator.generate(difficulty: difficulty, maxAttempts: 4000, using: &rng)
        }.value
        guard let p else { errorMessage = "Couldn't prepare today's puzzle."; return }
        start(p, dailyKey: key)
    }

    #if DEBUG
    /// Launch arguments run once per app launch (not per window).
    private static var appliedDebugArguments = false

    /// Screenshot/test hooks: `-puzzle <81> [-prefill n [-wrong]]`, `-demo <difficulty> [hintLevel] [-arm d]`.
    func applyDebugArguments() async {
        guard !Self.appliedDebugArguments else { return }
        Self.appliedDebugArguments = true
        let args = ProcessInfo.processInfo.arguments
        func value(after flag: String) -> String? {
            args.firstIndex(of: flag).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
        }
        #if os(macOS)
        // The Mac sidebar mounts the Play stack late and drops a push that's already
        // pending when it appears, so let the window settle first.
        try? await Task.sleep(for: .milliseconds(500))
        #endif
        if let p = value(after: "-puzzle"), let grid = Grid(p) {
            start(puzzle: grid)
            if let n = value(after: "-prefill").flatMap(Int.init) {
                game?.debugPrefill(leaving: n, wrong: args.contains("-wrong"))
            }
            return
        }
        guard let name = value(after: "-demo"),
              let d = Difficulty.allCases.first(where: { $0.name.lowercased() == name }) else { return }
        await newGame(d)
        guard let g = game else { return }
        g.fillNotes()
        g.selected = g.values.firstIndex(of: 0)
        if let digit = value(after: "-arm").flatMap(Int.init) {
            g.selected = nil
            g.tapDigit(digit, small: false)
        }
        if let i = args.firstIndex(of: "-demo"), i + 2 < args.count, let level = Int(args[i + 2]) {
            for _ in 0...level { g.requestHint() }
        }
    }
    #endif
}
