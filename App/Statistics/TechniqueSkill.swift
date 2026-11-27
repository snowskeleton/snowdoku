import Foundation
import SudokuCore

/// How a player does on one technique, summed over every move that needed it (`TechniqueMove`).
struct TechniqueSkill: Codable, Equatable {
    var moves = 0
    /// Moves made with no hint and no mistake.
    var unaided = 0
    var mistakes = 0
    /// Moves where the player asked for a hint.
    var hinted = 0
    /// Game time spent on unaided moves, for the average time to spot the technique.
    var unaidedSeconds = 0.0
    /// Whether each of the last `recentLimit` moves was unaided, oldest first, so the rating
    /// follows the player as they improve.
    var recent: [Bool] = []

    static let recentLimit = 20
    /// Fewer moves than this say too little to call a technique a strength or a weakness.
    static let minimumMoves = 3

    mutating func add(_ m: TechniqueMove) {
        moves += 1
        mistakes += m.mistakes
        if m.hintLevel != nil || m.applied { hinted += 1 }
        if m.unaided {
            unaided += 1
            unaidedSeconds += m.seconds
        }
        recent.append(m.unaided)
        if recent.count > Self.recentLimit { recent.removeFirst(recent.count - Self.recentLimit) }
    }

    /// The share of recent moves made unaided, 0...1.
    var recentRate: Double { recent.isEmpty ? 0 : Double(recent.filter { $0 }.count) / Double(recent.count) }
    var averageSeconds: Double? { unaided > 0 ? unaidedSeconds / Double(unaided) : nil }
    var isRated: Bool { recent.count >= Self.minimumMoves }
}
