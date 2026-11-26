import Charts
import SwiftUI
import SudokuCore

/// Stacked bars per tier: games solved, and games started but never finished.
struct DifficultyChart: View {
    let stats: Stats

    private struct Bar: Identifiable {
        let difficulty: Difficulty
        let status: String
        let count: Int
        var id: String { "\(difficulty.rawValue)-\(status)" }
    }

    private var bars: [Bar] {
        Difficulty.allCases.flatMap { d -> [Bar] in
            let started = stats.started[d] ?? 0
            let solved = stats.completed[d] ?? 0
            guard started > 0 || solved > 0 else { return [] }
            return [Bar(difficulty: d, status: "Solved", count: solved),
                    Bar(difficulty: d, status: "Not finished", count: max(0, started - solved))]
        }
    }

    var body: some View {
        Chart(bars) { bar in
            BarMark(x: .value("Difficulty", bar.difficulty.name), y: .value("Games", bar.count))
                .foregroundStyle(by: .value("Status", bar.status))
        }
        .chartForegroundStyleScale(["Solved": AnyShapeStyle(.tint), "Not finished": AnyShapeStyle(.gray.opacity(0.35))])
        .chartLegend(position: .top, alignment: .leading)
        .frame(height: 180)
    }
}
