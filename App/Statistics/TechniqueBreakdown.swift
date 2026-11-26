import SwiftUI
import SudokuCore

/// The hardest technique in each solved puzzle, most common first. Each row opens the technique.
struct TechniqueBreakdown: View {
    let solves: [SolveRecord]
    var limit = 8

    var body: some View {
        let counts = Dictionary(grouping: solves, by: \.hardest).mapValues(\.count)
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key.score < $1.key.score }
            .prefix(limit)
        let top = Double(counts.first?.value ?? 1)
        ForEach(counts, id: \.key) { technique, count in
            NavigationLink(value: technique) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(technique.name)
                        Spacer()
                        Text(count, format: .number).foregroundStyle(.secondary).monospacedDigit()
                    }
                    Gauge(value: Double(count), in: 0...top) {}
                        .gaugeStyle(.linearCapacity)
                        .labelsHidden()
                        .accessibilityHidden(true)
                }
            }
            .accessibilityLabel("\(technique.name), \(count) puzzles")
        }
    }
}
