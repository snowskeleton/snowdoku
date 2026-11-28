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
    /// Every finished game, oldest first. Only games finished since this was added are here.
    var solves: [SolveRecord] = []
    /// How the player does on each technique, from the moves that needed it (drills included).
    var skills: [Technique: TechniqueSkill] = [:]
    /// Techniques with at least one drill done (library or campaign), for Game Center.
    var drilled: Set<Technique> = []
    /// Digits whose every missing copy the player placed first in a puzzle they then solved without
    /// hints (Game Center's hidden "first" achievements).
    var digitsFirst: Set<Int> = []

    init() {}

    /// Missing keys fall back to their defaults, so stats saved by older versions still load.
    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        started = try c.decodeIfPresent([Difficulty: Int].self, forKey: .started) ?? [:]
        completed = try c.decodeIfPresent([Difficulty: Int].self, forKey: .completed) ?? [:]
        bestTime = try c.decodeIfPresent([Difficulty: Double].self, forKey: .bestTime) ?? [:]
        totalTime = try c.decodeIfPresent([Difficulty: Double].self, forKey: .totalTime) ?? [:]
        dailyCompleted = try c.decodeIfPresent(Set<String>.self, forKey: .dailyCompleted) ?? []
        streak = try c.decodeIfPresent(Int.self, forKey: .streak) ?? 0
        lastDaily = try c.decodeIfPresent(String.self, forKey: .lastDaily)
        solves = (try? c.decodeIfPresent([SolveRecord].self, forKey: .solves)) ?? []
        skills = (try? c.decodeIfPresent([Technique: TechniqueSkill].self, forKey: .skills)) ?? [:]
        drilled = (try? c.decodeIfPresent(Set<Technique>.self, forKey: .drilled)) ?? []
        digitsFirst = (try? c.decodeIfPresent(Set<Int>.self, forKey: .digitsFirst)) ?? []
    }
}
