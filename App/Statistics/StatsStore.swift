import Foundation
import Observation
import SudokuCore

/// App-wide statistics, shared by every window.
@Observable @MainActor
final class StatsStore {
    private(set) var stats = Stats()
    private let defaults = UserDefaults.standard

    init() {
        if let data = defaults.data(forKey: "stats"), let s = try? JSONDecoder().decode(Stats.self, from: data) {
            stats = s
        }
    }

    var isEmpty: Bool { stats.started.isEmpty && stats.dailyCompleted.isEmpty }
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
        if let key = g.dailyKey, !stats.dailyCompleted.contains(key) {
            stats.dailyCompleted.insert(key)
            let yesterday = DailySchedule.key(for: .now.addingTimeInterval(-86_400))
            stats.streak = stats.lastDaily == yesterday ? stats.streak + 1 : 1
            stats.lastDaily = key
        }
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(stats) { defaults.set(data, forKey: "stats") }
    }
}
