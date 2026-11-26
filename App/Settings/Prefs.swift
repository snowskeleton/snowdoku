import Foundation
import Observation
import SudokuCore

/// User preferences read by the model (views use @AppStorage with the same keys).
enum Prefs {
    static func bool(_ key: String, _ def: Bool) -> Bool { UserDefaults.standard.object(forKey: key) as? Bool ?? def }
    static var autoRemoveNotes: Bool { bool("autoRemoveNotes", true) }
    static var autoComplete: Bool { bool("autoComplete", true) }
    static var autoCompleteThreshold: Int { UserDefaults.standard.object(forKey: "autoCompleteThreshold") as? Int ?? 15 }
    /// Shift-click on a cell enters the armed digit as a note, even when the big digit is armed.
    static var shiftClickNotes: Bool { bool("shiftClickNotes", true) }
    /// Right-click on a cell removes the armed digit's note.
    static var rightClickRemovesNote: Bool { bool("rightClickRemovesNote", true) }
    /// The note kind for the notes pad, Shift and Fill.
    static var noteNotation: NoteNotation { NoteNotation(rawValue: UserDefaults.standard.string(forKey: "noteNotation") ?? "") ?? .manual }
    static var mistakeMode: MistakeMode { MistakeMode(rawValue: UserDefaults.standard.string(forKey: "mistakeMode") ?? "") ?? .conflicts }
}
