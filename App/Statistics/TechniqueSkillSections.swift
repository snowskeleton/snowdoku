import SwiftUI
import SudokuCore

/// The Statistics sections on technique skill: what to practice and what the player has down.
/// Each move counts toward the hardest technique it needed (`TechniqueMove`), and a technique is
/// judged on its recent moves made with no hint and no mistake.
struct TechniqueSkillSections: View {
    let skills: [Technique: TechniqueSkill]

    /// Below this unaided share a technique is worth practicing; at or above `strongFrom` it's a strength.
    static let weakBelow = 0.75
    static let strongFrom = 0.85

    private var rated: [(Technique, TechniqueSkill)] { skills.filter { $0.value.isRated }.map { ($0.key, $0.value) } }

    var body: some View {
        let weak = rated.filter { $0.1.recentRate < Self.weakBelow }
            .sorted { $0.1.recentRate != $1.1.recentRate ? $0.1.recentRate < $1.1.recentRate : $0.0.score < $1.0.score }
            .prefix(3)
        // The hardest techniques the player has down are the interesting strengths, not the singles.
        let strong = rated.filter { $0.1.recentRate >= Self.strongFrom }.sorted { $0.0.score > $1.0.score }.prefix(3)
        if !weak.isEmpty {
            Section {
                ForEach(weak, id: \.0) { TechniqueSkillRow(technique: $0.0, skill: $0.1) }
            } header: {
                Text("Worth practicing")
            } footer: {
                Text("Techniques you've recently needed a hint for or made a mistake on. Each page has a drill.")
            }
        }
        if !strong.isEmpty {
            Section("Strongest techniques") {
                ForEach(strong, id: \.0) { TechniqueSkillRow(technique: $0.0, skill: $0.1) }
            }
        }
        if !skills.isEmpty {
            Section {
                NavigationLink("All techniques") { TechniqueSkillsView(skills: skills) }
            } footer: {
                Text("Every digit you place counts toward the hardest technique it needed. The percentage is the share of your last \(TechniqueSkill.recentLimit) moves made with no hint and no mistake.")
            }
        }
    }
}
