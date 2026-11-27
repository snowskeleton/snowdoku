import SwiftUI
import SudokuCore

/// One technique's record: how often recent moves needing it were made unaided. Opens the technique.
struct TechniqueSkillRow: View {
    let technique: Technique
    let skill: TechniqueSkill

    var body: some View {
        NavigationLink(value: technique) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(technique.name)
                    Spacer()
                    Text(skill.recentRate, format: .percent.precision(.fractionLength(0)))
                        .foregroundStyle(.secondary).monospacedDigit()
                }
                Gauge(value: skill.recentRate) {}
                    .gaugeStyle(.linearCapacity)
                    .labelsHidden()
                    .tint(skill.recentRate < TechniqueSkillSections.weakBelow ? .orange : .green)
                    .accessibilityHidden(true)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(technique.name), \(Int((skill.recentRate * 100).rounded())) percent unaided, \(detail)")
    }

    private var detail: String {
        var parts = ["\(skill.moves.formatted()) \(skill.moves == 1 ? "move" : "moves")"]
        if skill.hinted > 0 { parts.append("\(skill.hinted.formatted()) with hints") }
        if skill.mistakes > 0 { parts.append("\(skill.mistakes.formatted()) \(skill.mistakes == 1 ? "mistake" : "mistakes")") }
        if let s = skill.averageSeconds { parts.append("about \(formatTime(s)) to spot") }
        return parts.joined(separator: " · ")
    }
}
