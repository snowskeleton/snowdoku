import SwiftUI
import SudokuCore

/// One tier in detail: how the solve times are trending, plus the numbers behind them.
struct DifficultyStatsView: View {
    let difficulty: Difficulty
    @Environment(StatsStore.self) private var store

    var body: some View {
        let stats = store.stats
        let solves = stats.solves.filter { $0.difficulty == difficulty }
        let solved = stats.completed[difficulty] ?? 0
        let started = stats.started[difficulty] ?? 0
        List {
            Section {
                SummaryTiles {
                    SummaryTile(title: "Solved", value: "\(solved) of \(started)", systemImage: "checkmark.circle")
                    SummaryTile(title: "Best (no hints)", value: stats.bestTime[difficulty].map(formatTime) ?? "–",
                                systemImage: "trophy")
                    SummaryTile(title: "Average",
                                value: solved > 0 ? formatTime((stats.totalTime[difficulty] ?? 0) / Double(solved)) : "–",
                                systemImage: "clock")
                    SummaryTile(title: "Last 10",
                                value: solves.isEmpty ? "–" : formatTime(Self.mean(solves.suffix(10).map(\.seconds))),
                                systemImage: "chart.line.downtrend.xyaxis")
                }
            }
            Section {
                if solves.isEmpty {
                    Text("Times are charted for games solved from now on.")
                        .foregroundStyle(.secondary)
                } else {
                    SolveTimeChart(solves: Array(solves.suffix(50)))
                }
            } header: {
                Text("Solve times")
            } footer: {
                if !solves.isEmpty { Text("The line is the average of your last five solves.") }
            }
            if !solves.isEmpty {
                Section("Per game") {
                    LabeledContent("Mistakes", value: Self.mean(solves.map { Double($0.mistakes) }),
                                   format: .number.precision(.fractionLength(1)))
                    LabeledContent("Hints", value: Self.mean(solves.map { Double($0.hintsUsed) }),
                                   format: .number.precision(.fractionLength(1)))
                    LabeledContent("Solved without hints",
                                   value: Double(solves.filter { $0.hintsUsed == 0 }.count) / Double(solves.count),
                                   format: .percent.precision(.fractionLength(0)))
                }
                Section("Recent") {
                    ForEach(solves.suffix(10).reversed()) { s in
                        LabeledContent {
                            Text(formatTime(s.seconds)).monospacedDigit()
                        } label: {
                            Text(s.date, format: .dateTime.month().day().hour().minute())
                            Text(Self.detail(s))
                        }
                    }
                }
            }
        }
        .navigationTitle(difficulty.name)
    }

    private static func mean(_ xs: [Double]) -> Double {
        xs.isEmpty ? 0 : xs.reduce(0, +) / Double(xs.count)
    }

    private static func detail(_ s: SolveRecord) -> String {
        var parts = [s.hardest.name]
        if s.daily { parts.append("Daily") }
        if s.hintsUsed > 0 { parts.append(s.hintsUsed == 1 ? "1 hint" : "\(s.hintsUsed) hints") }
        if s.mistakes > 0 { parts.append(s.mistakes == 1 ? "1 mistake" : "\(s.mistakes) mistakes") }
        return parts.joined(separator: " · ")
    }
}
