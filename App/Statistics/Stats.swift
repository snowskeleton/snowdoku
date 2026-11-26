import SudokuCore

/// Lifetime statistics, persisted as JSON in UserDefaults.
struct Stats: Codable, Equatable {
    var started: [Difficulty: Int] = [:]
    var completed: [Difficulty: Int] = [:]
    var bestTime: [Difficulty: Double] = [:]
    var totalTime: [Difficulty: Double] = [:]
    /// Daily keys (UTC dates, `DailySchedule.key`) that were solved.
    var dailyCompleted: Set<String> = []
    var streak = 0
    var lastDaily: String?
}
