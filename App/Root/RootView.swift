import SwiftUI
import SudokuCore

/// One window: its own game and tab selection, sharing app-wide statistics.
struct RootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var store: GameStore
    @State private var tab: AppTab = .play
    @State private var techniquePath: [Technique] = []
    @State private var playPath: [PlayRoute] = []

    init(stats: StatsStore, campaign: CampaignProgress) {
        _store = State(initialValue: GameStore(stats: stats, campaign: campaign))
    }

    var body: some View {
        TabView(selection: $tab) {
            Tab("Play", systemImage: "square.grid.3x3", value: .play) {
                NavigationStack(path: $playPath) {
                    HomeView()
                        .navigationDestination(for: PlayRoute.self, destination: playDestination)
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
            if playing {
                tab = .play
                if playPath.last != .game { playPath.append(.game) }
            } else {
                if playPath.last == .game { playPath.removeLast() }
                store.leaveGame()
            }
        }
        // A Game Center activity: open its chapter, or start today's daily.
        .onChange(of: GameCenter.shared.requestedActivity) { _, activity in
            guard let activity else { return }
            GameCenter.shared.requestedActivity = nil
            tab = .play
            switch activity {
            case .chapter(let id): playPath = [.campaign, .chapter(id)]
            case .daily: Task { await store.daily() }
            }
        }
        // The back button or a swipe popped the board.
        .onChange(of: playPath) { _, path in
            if path.last != .game && store.isPlaying { store.isPlaying = false }
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

    @ViewBuilder func playDestination(_ route: PlayRoute) -> some View {
        switch route {
        case .campaign: CampaignView()
        case .chapter(let id): if let ch = CampaignChapter.named(id) { ChapterView(chapter: ch) }
        case .lesson(let t): TechniqueDetailView(technique: t)
        case .freePlay: FreePlayView()
        case .freePlayTier(let d): FreePlayLevelsView(tier: d)
        case .game:
            if let game = store.game {
                GameView(game: game)
                    #if os(iOS)
                    .toolbarVisibility(.hidden, for: .tabBar)
                    #endif
            }
        }
    }
}
