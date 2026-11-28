import SwiftUI
import SudokuCore

/// The Play tab: Continue, the daily, the campaign and free play.
struct HomeView: View {
    @Environment(GameStore.self) private var store
    @Environment(StatsStore.self) private var stats
    @Environment(CampaignProgress.self) private var campaign

    var body: some View {
        List {
            Section {} header: {
                Text("No ads. No nonsense. Just sudoku.")
                    .font(.subheadline)
                    .textCase(nil)
            }

            if let action = store.continueAction {
                Section {
                    Button { Task { await store.performContinue() } } label: {
                        Label {
                            VStack(alignment: .leading) {
                                Text("Continue").font(.headline)
                                Text(subtitle(action)).font(.subheadline).foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "play.fill")
                        }
                    }
                    .accessibilityIdentifier("continue")
                }
            }

            Section {
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
                NavigationLink(value: PlayRoute.campaign) {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Campaign").font(.headline)
                            Text(campaignSubtitle).font(.subheadline).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "map")
                    }
                }
                NavigationLink(value: PlayRoute.freePlay) {
                    Label {
                        VStack(alignment: .leading) {
                            Text("Free Play").font(.headline)
                            Text("Any level, Beginner 1 to Extreme").font(.subheadline).foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "square.grid.3x3")
                    }
                }
            }
        }
        .navigationTitle("Snowdoku")
        .onAppear {
            store.reloadSaved()
            GameCenter.shared.showAccessPoint(true)
        }
        .onDisappear { GameCenter.shared.showAccessPoint(false) }
        .onChange(of: GameCenter.shared.isAuthenticated) { _, _ in GameCenter.shared.showAccessPoint(true) }
    }

    func subtitle(_ a: GameStore.ContinueAction) -> String {
        switch a {
        case .resume(let s): "\(s.title) · \(formatTime(s.record.elapsed))"
        case .campaign(let ch, let step): "\(ch.title) · \(ch.title(for: step))"
        case .newGame(let l): "\(l.name) · new game"
        }
    }

    var campaignSubtitle: String {
        let done = campaign.completedChapters
        if done == 0 { return "Learn every technique, one chapter at a time" }
        return "\(done) of \(CampaignChapter.all.count) chapters done"
    }

    var dailySubtitle: String {
        let level = Daily.level(for: DailySchedule.difficulty()).name
        return stats.stats.streak > 0 ? "\(level) · \(stats.stats.streak)-day streak" : level
    }

    func startDaily() {
        Task { await store.daily() }
    }
}
