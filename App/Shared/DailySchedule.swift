import Foundation
import SudokuCore

/// Which puzzle is "today's". Days are UTC so everyone gets the same daily puzzle
/// at the same moment, wherever they are.
enum DailySchedule {
    private static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = .gmt
        return c
    }()

    /// "2026-11-26" for the UTC day containing `date`.
    static func key(for date: Date = .now) -> String {
        date.formatted(.iso8601.year().month().day())
    }

    /// Difficulty ramps through the (UTC) week: Monday easy … Sunday master.
    static func difficulty(for date: Date = .now) -> Difficulty {
        let weekday = calendar.component(.weekday, from: date) // 1 = Sunday
        return [.master, .easy, .easy, .medium, .hard, .hard, .expert][weekday - 1]
    }

    /// Generator seed for the UTC day containing `date`.
    static func seed(for date: Date = .now) -> UInt64 {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return Daily.seed(year: c.year ?? 2000, month: c.month ?? 1, day: c.day ?? 1)
    }
}
