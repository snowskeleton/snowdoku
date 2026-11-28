import Foundation
import Observation
import SudokuCore

/// App-wide statistics, shared by every window.
@Observable @MainActor
final class StatsStore {
    private(set) var stats = Stats()
    private let defaults = UserDefaults.standard
    /// Solve reports for crowd-sourced difficulty grading, waiting for a server.
    let reports = ReportQueue()

    init() {
        if let data = defaults.data(forKey: "stats"), let s = try? JSONDecoder().decode(Stats.self, from: data) {
            stats = s
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-sampleStats") { stats = Self.sample() }
        #endif
    }

    var isEmpty: Bool { stats.started.isEmpty && stats.dailyCompleted.isEmpty && stats.skills.isEmpty }
    var dailyDone: Bool { stats.dailyCompleted.contains(DailySchedule.key()) }

    func recordStart(_ difficulty: Difficulty) {
        stats.started[difficulty, default: 0] += 1
        save()
    }

    func recordCompletion(_ g: Game) {
        let d = g.difficulty
        let t = g.elapsed()
        stats.completed[d, default: 0] += 1
        stats.totalTime[d, default: 0] += t
        if g.hintsUsed == 0 { stats.bestTime[d] = min(stats.bestTime[d] ?? .infinity, t) }
        stats.solves.append(SolveRecord(id: g.id, date: .now, difficulty: d, seconds: t, mistakes: g.mistakes,
                                        hintsUsed: g.hintsUsed, hardest: g.hardest, daily: g.dailyKey != nil))
        if let key = g.dailyKey, !stats.dailyCompleted.contains(key) {
            stats.dailyCompleted.insert(key)
            let yesterday = DailySchedule.key(for: .now.addingTimeInterval(-86_400))
            stats.streak = stats.lastDaily == yesterday ? stats.streak + 1 : 1
            stats.lastDaily = key
        }
        if g.hintsUsed == 0, let d = g.digitFirst { stats.digitsFirst.insert(d) }
        save()
        GameCenter.shared.reportStats(self)
    }

    /// A drill's move was made (any drill but a lesson question).
    func recordDrill(_ technique: Technique) {
        guard !stats.drilled.contains(technique) else { return }
        stats.drilled.insert(technique)
        save()
        GameCenter.shared.reportStats(self)
    }

    /// Adds a finished game's (or found drill's) moves to the technique skills, and queues its
    /// solve report. Each game counts once.
    func recordMoves(_ g: Game) async {
        guard !g.movesRecorded else { return }
        g.movesRecorded = true
        let moves = await g.finishedMoves()
        guard !moves.isEmpty else { return }
        for m in moves where m.technique != .bruteForce { stats.skills[m.technique, default: TechniqueSkill()].add(m) }
        save()
        reports.enqueue(SolveReport(g, moves: moves, installID: reports.installID))
    }

    #if DEBUG
    /// Made-up history for screenshots (`-sampleStats`); never saved.
    private static func sample() -> Stats {
        var s = Stats()
        var rng = SystemRandomNumberGenerator()
        let tiers: [(Difficulty, Double, [Technique])] = [
            (.easy, 300, [.hiddenSingleBox, .nakedSingle]),
            (.medium, 520, [.pointing, .claiming, .nakedPair]),
            (.hard, 900, [.hiddenPair, .xWing, .nakedTriple]),
            (.expert, 1500, [.xyWing, .skyscraper, .simpleColoring]),
        ]
        for day in (0..<120).reversed() {
            let date = Date.now.addingTimeInterval(-Double(day) * 86_400)
            if Int.random(in: 0..<10, using: &rng) < 7 { s.dailyCompleted.insert(DailySchedule.key(for: date)) }
            for _ in 0..<Int.random(in: 0...1, using: &rng) {
                let (d, base, techniques) = tiers.randomElement(using: &rng)!
                let progress = 1 - 0.35 * Double(120 - day) / 120
                let seconds = base * progress * Double.random(in: 0.75...1.3, using: &rng)
                let hints = Int.random(in: 0..<5, using: &rng) == 0 ? Int.random(in: 1...3, using: &rng) : 0
                s.solves.append(SolveRecord(id: UUID(), date: date, difficulty: d, seconds: seconds,
                                            mistakes: Int.random(in: 0...2, using: &rng), hintsUsed: hints,
                                            hardest: techniques.randomElement(using: &rng)!, daily: false))
                s.started[d, default: 0] += 1
                s.completed[d, default: 0] += 1
                s.totalTime[d, default: 0] += seconds
                if hints == 0 { s.bestTime[d] = min(s.bestTime[d] ?? .infinity, seconds) }
            }
        }
        for d in [Difficulty.easy, .hard, .expert] { s.started[d, default: 0] += Int.random(in: 1...6, using: &rng) }
        // Strong on the basics, shakier the harder the technique.
        let skilled: [(Technique, Int, Double)] = [
            (.fullHouse, 200, 0.99), (.hiddenSingleBox, 900, 0.97), (.hiddenSingleLine, 400, 0.92),
            (.nakedSingle, 600, 0.9), (.pointing, 120, 0.85), (.claiming, 60, 0.6), (.nakedPair, 50, 0.8),
            (.hiddenPair, 25, 0.45), (.xWing, 12, 0.5), (.xyWing, 8, 0.25), (.skyscraper, 6, 0.7),
        ]
        for (t, n, rate) in skilled {
            for _ in 0..<n {
                let ok = Double.random(in: 0..<1, using: &rng) < rate
                s.skills[t, default: TechniqueSkill()].add(TechniqueMove(
                    technique: t, seconds: Double(t.score) / 4 * Double.random(in: 0.5...2, using: &rng), at: 0,
                    mistakes: ok ? 0 : Int.random(in: 0...1, using: &rng), hintLevel: ok ? nil : 2, applied: false))
            }
        }
        return s
    }
    #endif

    private func save() {
        if let data = try? JSONEncoder().encode(stats) { defaults.set(data, forKey: "stats") }
    }
}
