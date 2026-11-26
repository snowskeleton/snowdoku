import SwiftUI
import SudokuCore

struct StatsView: View {
    @Environment(StatsStore.self) private var store

    var body: some View {
        List {
            Section("Daily") {
                LabeledContent("Completed", value: store.stats.dailyCompleted.count, format: .number)
                LabeledContent("Current streak", value: store.stats.streak, format: .number)
            }
            ForEach(Difficulty.allCases.filter { (store.stats.started[$0] ?? 0) > 0 }, id: \.self) { d in
                Section(d.name) {
                    let done = store.stats.completed[d] ?? 0
                    LabeledContent("Solved", value: "\(done) of \(store.stats.started[d] ?? 0)")
                    if let best = store.stats.bestTime[d] { LabeledContent("Best (no hints)", value: formatTime(best)) }
                    if done > 0 { LabeledContent("Average", value: formatTime((store.stats.totalTime[d] ?? 0) / Double(done))) }
                }
            }
        }
        .overlay {
            if store.isEmpty {
                ContentUnavailableView(
                    "No games yet",
                    systemImage: "chart.bar",
                    description: Text("Your solve counts, streaks and best times will show up here.")
                )
            }
        }
        .navigationTitle("Statistics")
    }
}
