import Foundation

/// Streaks worked out from the set of solved daily keys (UTC days are always 86 400 s long).
enum DailyStreaks {
    /// Consecutive solved days ending today, or ending yesterday if today isn't solved yet.
    static func current(_ keys: Set<String>, now: Date = .now) -> Int {
        var day = keys.contains(DailySchedule.key(for: now)) ? now : now.addingTimeInterval(-86_400)
        var n = 0
        while keys.contains(DailySchedule.key(for: day)) {
            n += 1
            day = day.addingTimeInterval(-86_400)
        }
        return n
    }

    static func longest(_ keys: Set<String>) -> Int {
        let days = keys.compactMap { try? Date($0 + "T00:00:00Z", strategy: .iso8601) }.sorted()
        var best = 0, run = 0
        var previous: Date?
        for d in days {
            run = previous.map { d.timeIntervalSince($0) == 86_400 } == true ? run + 1 : 1
            best = max(best, run)
            previous = d
        }
        return best
    }
}
