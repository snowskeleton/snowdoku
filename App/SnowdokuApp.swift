import SwiftUI
import SudokuCore

@main
struct SnowdokuApp: App {
    @State private var store = GameStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
        #if os(macOS)
        .defaultSize(width: 720, height: 900)
        #endif
    }
}

enum AppTab: Hashable { case play, techniques, statistics, settings }

struct RootView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .play

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                HomeView()
                    .navigationDestination(isPresented: Binding(
                        get: { store.isPlaying },
                        set: { if !$0 { store.leaveGame() } }
                    )) {
                        if let game = store.game {
                            GameView(game: game)
                                #if os(iOS)
                                .toolbar(.hidden, for: .tabBar)
                                #endif
                        }
                    }
            }
            .tabItem { Label("Play", systemImage: "square.grid.3x3") }
            .tag(AppTab.play)

            NavigationStack { TechniqueLibraryView() }
                .tabItem { Label("Techniques", systemImage: "book") }
                .tag(AppTab.techniques)

            NavigationStack { StatsView() }
                .tabItem { Label("Statistics", systemImage: "chart.bar") }
                .tag(AppTab.statistics)

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(AppTab.settings)
        }
        // Starting a game from any tab (e.g. Practice in Techniques) lands on the board.
        .onChange(of: store.isPlaying) { _, playing in if playing { tab = .play } }
        // Generation can start from Play or Techniques, so block the whole app while it runs.
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
        #if DEBUG
        .task {
            // Screenshot/demo hook: `-demo <difficulty> [hintLevel]`
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-puzzle"), i + 1 < args.count, let grid = Grid(args[i + 1]) {
                store.start(puzzle: grid)
                if let j = args.firstIndex(of: "-prefill"), j + 1 < args.count, let n = Int(args[j + 1]) {
                    store.game?.debugPrefill(leaving: n, wrong: args.contains("-wrong"))
                }
                return
            }
            if let i = args.firstIndex(of: "-demo"), i + 1 < args.count,
               let d = Difficulty.allCases.first(where: { $0.name.lowercased() == args[i + 1] }) {
                await store.newGame(d)
                guard let g = store.game else { return }
                g.fillNotes()
                g.selected = g.values.firstIndex(of: 0)
                if let j = args.firstIndex(of: "-arm"), j + 1 < args.count, let d = Int(args[j + 1]) {
                    g.selected = nil
                    g.tapDigit(d, small: false)
                }
                if i + 2 < args.count, let lvl = Int(args[i + 2]) {
                    for _ in 0...lvl { g.requestHint() }
                }
            }
        }
        #endif
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.game?.resumeClock() } else { store.game?.pauseClock(); store.save() }
        }
    }
}
