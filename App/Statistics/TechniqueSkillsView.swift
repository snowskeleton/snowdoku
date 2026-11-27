import SwiftUI
import SudokuCore

/// Every technique the player has needed, grouped by difficulty, with their record on it.
struct TechniqueSkillsView: View {
    let skills: [Technique: TechniqueSkill]

    var body: some View {
        let tiers = Dictionary(grouping: skills.keys, by: \.difficulty)
        List {
            ForEach(Difficulty.allCases.filter { tiers[$0] != nil }, id: \.self) { d in
                Section(d.name) {
                    ForEach(tiers[d]!.sorted { $0.score < $1.score }, id: \.self) { t in
                        TechniqueSkillRow(technique: t, skill: skills[t]!)
                    }
                }
            }
        }
        .navigationTitle("Techniques")
    }
}
