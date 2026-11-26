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
        .defaultSize(width: 900, height: 900)
        #endif

        #if os(macOS)
        Settings {
            SettingsView()
                .frame(width: 460)
        }
        #endif
    }
}

struct RootView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab: AppTab = .play

    var body: some View {
        @Bindable var store = store
        TabView(selection: $tab) {
            Tab("Play", systemImage: "square.grid.3x3", value: .play) {
                NavigationStack {
                    HomeView()
                        .navigationDestination(isPresented: $store.isPlaying) {
                            if let game = store.game {
                                GameView(game: game)
                                    #if os(iOS)
                                    .toolbarVisibility(.hidden, for: .tabBar)
                                    #endif
                            }
                        }
                }
            }
            Tab("Techniques", systemImage: "book", value: .techniques) {
                NavigationStack { TechniqueLibraryView() }
            }
            Tab("Statistics", systemImage: "chart.bar", value: .statistics) {
                NavigationStack { StatsView() }
            }
            #if os(iOS)
            // On the Mac, settings live in the standard Settings window (Command-comma).
            Tab("Settings", systemImage: "gear", value: .settings) {
                NavigationStack { SettingsView() }
            }
            #endif
        }
        // A tab bar on iPhone, a collapsible sidebar on iPad and Mac.
        .tabViewStyle(.sidebarAdaptable)
        // Leaving the board (back button or swipe) pauses and saves.
        .onChange(of: store.isPlaying) { _, playing in
            if playing { tab = .play } else { store.leaveGame() }
        }
        // Generation can start from Play or Techniques, so block the whole app while it runs.
        .disabled(store.generating != nil)
        .overlay {
            if let msg = store.generating {
                ProgressView(msg)
                    .padding(24)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            }
        }
        .alert("Hmm", item: $store.errorMessage) { _ in } message: { Text($0) }
        #if DEBUG
        .task {
            // Screenshot/demo hook: `-demo <difficulty> [hintLevel]`
            let args = ProcessInfo.processInfo.arguments
            #if os(macOS)
            // The Mac sidebar mounts the Play stack late and drops a push that's already
            // pending when it appears, so let the window settle first.
            try? await Task.sleep(for: .milliseconds(500))
            #endif
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
