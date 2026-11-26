import SwiftUI
import SudokuCore

struct HomeView: View {
    @Environment(GameStore.self) private var store
    @Environment(StatsStore.self) private var stats

    var body: some View {
        List {
            Section {} header: {
                Text("No ads. No nonsense. Just sudoku.")
                    .font(.subheadline)
                    .textCase(nil)
            }

            if store.hasGameInProgress, let g = store.game {
                Section {
                    Button(action: store.resume) {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Continue").font(.headline)
                                Text("\(g.title) · \(formatTime(g.elapsed()))")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "play.fill")
                        }
                    }
                }
            }

            Section("Daily") {
                Button(action: startDaily) {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Today's puzzle").font(.headline)
                            Text(dailySubtitle).font(.subheadline).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: stats.dailyDone ? "checkmark.circle.fill" : "calendar")
                            .foregroundStyle(stats.dailyDone ? .green : .accentColor)
                    }
                }
            }

            Section("New game") {
                ForEach(GameStore.playable, id: \.self) { d in
                    Button { startNewGame(d) } label: {
                        VStack(alignment: .leading) {
                            Text(d.name).font(.headline)
                            Text(Technique.tierBlurbs[d] ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                }
            }
        }
        .navigationTitle("Snowdoku")
    }

    var dailySubtitle: String {
        let level = DailySchedule.difficulty().name
        return stats.stats.streak > 0 ? "\(level) · \(stats.stats.streak)-day streak" : level
    }

    func startDaily() {
        Task { await store.daily() }
    }

    func startNewGame(_ difficulty: Difficulty) {
        Task { await store.newGame(difficulty) }
    }
}
