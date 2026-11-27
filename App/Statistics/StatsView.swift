import SwiftUI
import SudokuCore

struct StatsView: View {
    @Environment(StatsStore.self) private var store
    #if DEBUG
    @State private var debugDetail: Difficulty?
    #endif

    private var stats: Stats { store.stats }
    private var played: [Difficulty] {
        Difficulty.allCases.filter { (stats.started[$0] ?? 0) > 0 || (stats.completed[$0] ?? 0) > 0 }
    }

    var body: some View {
        List {
            if !store.isEmpty {
                Section {
                    SummaryTiles {
                        SummaryTile(title: "Solved", value: stats.completed.values.reduce(0, +).formatted(),
                                    systemImage: "checkmark.circle")
                        SummaryTile(title: "Time played", value: formatTime(stats.totalTime.values.reduce(0, +)),
                                    systemImage: "clock")
                        SummaryTile(title: "Daily streak", value: DailyStreaks.current(stats.dailyCompleted).formatted(),
                                    systemImage: "flame")
                        SummaryTile(title: "Longest streak", value: DailyStreaks.longest(stats.dailyCompleted).formatted(),
                                    systemImage: "trophy")
                    }
                }
                Section("Daily puzzles") {
                    DailyHeatmap(solved: stats.dailyCompleted)
                    LabeledContent("Solved", value: stats.dailyCompleted.count, format: .number)
                }
            }
            if !played.isEmpty {
                Section("By difficulty") {
                    DifficultyChart(stats: stats)
                    ForEach(played, id: \.self) { d in
                        NavigationLink(value: d) {
                            LabeledContent(d.name) {
                                Text("\(stats.completed[d] ?? 0) of \(stats.started[d] ?? 0)")
                            }
                        }
                    }
                }
            }
            if !stats.solves.isEmpty {
                Section {
                    TechniqueBreakdown(solves: stats.solves)
                } header: {
                    Text("Hardest technique needed")
                } footer: {
                    Text("The toughest step in each puzzle you've solved.")
                }
            }
            TechniqueSkillSections(skills: stats.skills)
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
        .navigationDestination(for: Difficulty.self) { DifficultyStatsView(difficulty: $0) }
        .navigationDestination(for: Technique.self, destination: TechniqueDetailView.init)
        #if DEBUG
        .navigationDestination(item: $debugDetail) { DifficultyStatsView(difficulty: $0) }
        .task {
            let args = ProcessInfo.processInfo.arguments
            try? await Task.sleep(for: .milliseconds(600))
            if let i = args.firstIndex(of: "-statsDetail"), i + 1 < args.count {
                debugDetail = Difficulty.allCases.first { $0.name.lowercased() == args[i + 1] }
            }
        }
        #endif
    }
}
