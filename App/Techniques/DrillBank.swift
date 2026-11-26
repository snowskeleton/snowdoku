import Foundation
import SudokuCore

/// Training positions bundled with the app (`Resources/Drills.json`, mined with `sudokugen drills`).
enum DrillBank {
    /// Drills by technique, in the order they were mined. Loaded on first use.
    static let all: [Technique: [Drill]] = {
        guard let url = Bundle.main.url(forResource: "Drills", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([Drill].self, from: data) else { return [:] }
        return Dictionary(grouping: list, by: \.technique)
    }()

    static func hasDrills(for t: Technique) -> Bool { all[t]?.isEmpty == false }

    /// A random drill, randomly transformed.
    static func random(for t: Technique) -> Drill? {
        var rng = SystemRandomNumberGenerator()
        return all[t]?.randomElement(using: &rng)?.transformed(by: .random(using: &rng))
    }

    /// The drill shown as the worked example on a technique's page (always the same one).
    static func example(for t: Technique) -> Drill? { all[t]?.first }
}
