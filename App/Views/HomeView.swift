import SwiftUI
import SudokuCore

struct HomeView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Snowdoku").font(.largeTitle.bold())
                    Text("No ads. No nonsense. Just sudoku.").foregroundStyle(.secondary)
                }
                .listRowBackground(Color.clear)
            }

            if store.hasGameInProgress, let g = store.game {
                Section {
                    Button { store.resume() } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            VStack(alignment: .leading) {
                                Text("Continue").font(.headline)
                                Text("\(g.practice.map { "Practice: \($0.name)" } ?? g.difficulty.name) · \(formatTime(g.elapsed()))")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Section("Daily") {
                Button { Task { await store.daily() } } label: {
                    HStack {
                        Image(systemName: store.dailyDone ? "checkmark.circle.fill" : "calendar")
                            .foregroundStyle(store.dailyDone ? .green : .accentColor)
                        VStack(alignment: .leading) {
                            Text("Today's puzzle").font(.headline)
                            Text("\(GameStore.dailyDifficulty().name)\(store.stats.streak > 0 ? " · \(store.stats.streak)-day streak" : "")")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Section("New game") {
                ForEach(GameStore.playable, id: \.self) { d in
                    Button { Task { await store.newGame(d) } } label: {
                        VStack(alignment: .leading) {
                            Text(d.name).font(.headline)
                            Text(blurb(d)).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                }
            }

            Section {
                NavigationLink { TechniqueLibraryView() } label: { Label("Techniques", systemImage: "book") }
                NavigationLink { StatsView() } label: { Label("Statistics", systemImage: "chart.bar") }
                NavigationLink { SettingsView() } label: { Label("Settings", systemImage: "gear") }
            }
        }
        .disabled(store.generating != nil)
        .overlay {
            if let msg = store.generating {
                ProgressView(msg)
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .alert("Hmm", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.errorMessage ?? "")
        }
        #if os(iOS)
        .navigationBarHidden(true)
        #endif
    }

    func blurb(_ d: Difficulty) -> String {
        Technique.allCases.filter { $0.difficulty == d && $0 != .bruteForce }.prefix(4).map(\.name).joined(separator: ", ")
    }
}

struct TechniqueLibraryView: View {
    var body: some View {
        List {
            ForEach(Difficulty.allCases, id: \.self) { d in
                Section(d.name) {
                    ForEach(Technique.allCases.filter { $0.difficulty == d && $0 != .bruteForce }, id: \.self) { t in
                        NavigationLink { TechniqueDetailView(technique: t) } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.name)
                                Text(t.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Techniques")
    }
}

struct TechniqueDetailView: View {
    let technique: Technique
    @Environment(GameStore.self) private var store

    var body: some View {
        List {
            Section {
                LabeledContent("Difficulty", value: technique.difficulty.name)
                LabeledContent("Score", value: "\(technique.score)")
                if technique.assumesUniqueness {
                    Text("Relies on the puzzle having exactly one solution.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("Idea") {
                Text(technique.summary)
            }
            Section {
                Button {
                    Task { await store.practice(technique) }
                } label: {
                    Label("Practice with a puzzle that needs it", systemImage: "graduationcap")
                }
            } footer: {
                Text("Generates a puzzle whose logical solution uses \(technique.name). Ask for hints at the technique level to find it.")
            }
        }
        .navigationTitle(technique.name)
        .disabled(store.generating != nil)
        .overlay {
            if let msg = store.generating {
                ProgressView(msg).padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}

struct StatsView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        List {
            Section("Daily") {
                LabeledContent("Completed", value: "\(store.stats.dailyCompleted.count)")
                LabeledContent("Current streak", value: "\(store.stats.streak)")
            }
            ForEach(Difficulty.allCases, id: \.self) { d in
                let started = store.stats.started[d] ?? 0
                if started > 0 {
                    Section(d.name) {
                        let done = store.stats.completed[d] ?? 0
                        LabeledContent("Solved", value: "\(done) of \(started)")
                        if let best = store.stats.bestTime[d] { LabeledContent("Best (no hints)", value: formatTime(best)) }
                        if done > 0 { LabeledContent("Average", value: formatTime((store.stats.totalTime[d] ?? 0) / Double(done))) }
                    }
                }
            }
        }
        .navigationTitle("Statistics")
    }
}

struct SettingsView: View {
    @AppStorage("mistakeMode") private var mistakeMode: MistakeMode = .conflicts
    @AppStorage("autoRemoveNotes") private var autoRemoveNotes = true
    @AppStorage("highlightSame") private var highlightSame = true
    @AppStorage("highlightPeers") private var highlightPeers = true
    @AppStorage("showTimer") private var showTimer = true

    var body: some View {
        Form {
            Section("Mistakes") {
                Picker("Show mistakes", selection: $mistakeMode) {
                    ForEach(MistakeMode.allCases) { Text($0.label).tag($0) }
                }
            }
            Section("Assistance") {
                Toggle("Remove notes when placing a digit", isOn: $autoRemoveNotes)
                Toggle("Highlight matching digits", isOn: $highlightSame)
                Toggle("Highlight row, column and box", isOn: $highlightPeers)
            }
            Section("Display") {
                Toggle("Show timer", isOn: $showTimer)
            }
        }
        .navigationTitle("Settings")
    }
}
