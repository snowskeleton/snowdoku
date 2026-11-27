import SwiftUI
import SudokuCore

struct HomeView: View {
    @Environment(GameStore.self) private var store
    @Environment(StatsStore.self) private var stats
    /// The tier whose "Continue or new game?" question is showing.
    @State private var choosing: Difficulty?

    var body: some View {
        List {
            Section {} header: {
                Text("No ads. No nonsense. Just sudoku.")
                    .font(.subheadline)
                    .textCase(nil)
            }

            if let recent = store.mostRecent {
                Section {
                    Button { store.continueGame(recent.record.slot) } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Continue").font(.headline)
                                Text("\(recent.title) · \(formatTime(recent.record.elapsed))")
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
                    Button { tapNewGame(d) } label: {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading) {
                                Text(d.name).font(.headline)
                                Text(Technique.tierBlurbs[d] ?? "").font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                            Spacer(minLength: 8)
                            if let s = store.savedGame(.random(d)) {
                                Text("In progress · \(formatTime(s.record.elapsed))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Snowdoku")
        .onAppear(perform: store.reloadSaved)
        .confirmationDialog("Continue or new game?", isPresented: Binding { choosing != nil } set: { if !$0 { choosing = nil } }, titleVisibility: .visible, presenting: choosing) { d in
            Button("Continue") { store.continueGame(.random(d)) }
            Button("New game", role: .destructive) { startNewGame(d) }
            Button("Cancel", role: .cancel) {}
        } message: { d in
            if let s = store.savedGame(.random(d)) {
                Text("You have a \(d.name.lowercased()) game in progress (\(formatTime(s.record.elapsed))). A new game replaces it.")
            }
        }
    }

    /// A tier with an unfinished game asks whether to continue it.
    func tapNewGame(_ d: Difficulty) {
        if store.savedGame(.random(d)) != nil { choosing = d } else { startNewGame(d) }
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
