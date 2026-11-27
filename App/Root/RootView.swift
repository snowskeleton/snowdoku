import SwiftUI
import SudokuCore

/// One window: its own game and tab selection, sharing app-wide statistics.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store: GameStore
    @State private var tab: AppTab = .play
    @State private var techniquePath: [Technique] = []

    init(stats: StatsStore) {
        _store = State(initialValue: GameStore(stats: stats))
    }

    var body: some View {
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
                NavigationStack(path: $techniquePath) { TechniqueLibraryView() }
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
        .environment(store)
        #if DEBUG
        .task {
            let args = ProcessInfo.processInfo.arguments
            if args.contains("-statsTab") { tab = .statistics }
            if let i = args.firstIndex(of: "-technique"), i + 1 < args.count, let t = Technique(rawValue: args[i + 1]) {
                tab = .techniques
                techniquePath = [t]
            }
            await store.applyDebugArguments()
        }
        #endif
        .onChange(of: scenePhase) { _, phase in
            // Only a game on screen has anything new to save; saving one left at Home would
            // mark it most recent and could overwrite another window's copy of it.
            guard store.isPlaying else { if phase == .active { store.reloadSaved() }; return }
            if phase == .active { store.game?.resumeClock() } else { store.game?.pauseClock(); store.save() }
        }
    }
}
