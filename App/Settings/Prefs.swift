import Foundation
import Observation
import SudokuCore

/// User preferences read by the model (views use @AppStorage with the same keys).
enum Prefs {
    static func bool(_ key: String, _ def: Bool) -> Bool { UserDefaults.standard.object(forKey: key) as? Bool ?? def }
    static var autoRemoveNotes: Bool { bool("autoRemoveNotes", true) }
    static var autoComplete: Bool { bool("autoComplete", true) }
    static var autoCompleteThreshold: Int { UserDefaults.standard.object(forKey: "autoCompleteThreshold") as? Int ?? 15 }
    static var mistakeMode: MistakeMode { MistakeMode(rawValue: UserDefaults.standard.string(forKey: "mistakeMode") ?? "") ?? .conflicts }
}
