import Foundation

/// An unfinished game in its slot, with when it was last played.
struct SavedGame: Codable {
    var record: GameRecord
    var savedAt: Date

    /// As `Game.title`.
    var title: String {
        if let drill = record.drill { return "Drill: \(drill.technique.name)" }
        if let practice = record.practice { return "Practice: \(practice.name)" }
        return record.dailyKey != nil ? "Daily" : record.difficulty.name
    }
}

/// The unfinished games of every slot, in `UserDefaults`. Shared by all windows.
enum SavedGames {
    private static let key = "savedGames"
    private static var defaults: UserDefaults { .standard }

    static func load() -> [String: SavedGame] {
        if let data = defaults.data(forKey: key), let all = try? JSONDecoder().decode([String: SavedGame].self, from: data) {
            return all
        }
        // Before slots there was a single saved game.
        if let data = defaults.data(forKey: "currentGame"), let r = try? JSONDecoder().decode(GameRecord.self, from: data) {
            defaults.removeObject(forKey: "currentGame")
            guard !r.completed else { return [:] }
            let all = [r.slot.key: SavedGame(record: r, savedAt: .now)]
            store(all)
            return all
        }
        return [:]
    }

    static func store(_ all: [String: SavedGame]) {
        if let data = try? JSONEncoder().encode(all) { defaults.set(data, forKey: key) }
    }
}
