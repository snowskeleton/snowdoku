import Foundation
import SudokuCore

/// What the player was last doing, for the Play tab's Continue button: the campaign, or free
/// play at a level. Dailies and library drills don't change it. Shared by every window.
enum LastActivity: Codable, Equatable {
    case campaign
    /// Free play at all of a tier's levels ("All Medium"; also what saves from before levels mean).
    case freePlay(Difficulty)
    case freePlayLevel(Level)

    private static let key = "lastActivity"

    static var current: LastActivity? {
        get {
            UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(LastActivity.self, from: $0) }
        }
        set {
            guard let newValue else { UserDefaults.standard.removeObject(forKey: key); return }
            if let data = try? JSONEncoder().encode(newValue) { UserDefaults.standard.set(data, forKey: key) }
        }
    }
}
