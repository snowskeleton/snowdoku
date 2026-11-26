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

struct RootView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            HomeView()
                .navigationDestination(isPresented: Binding(
                    get: { store.isPlaying },
                    set: { if !$0 { store.leaveGame() } }
                )) {
                    if let game = store.game {
                        GameView(game: game)
                    }
                }
        }
        #if DEBUG
        .task {
            // Screenshot/demo hook: `-demo <difficulty> [hintLevel]`
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-demo"), i + 1 < args.count,
               let d = Difficulty.allCases.first(where: { $0.name.lowercased() == args[i + 1] }) {
                await store.newGame(d)
                guard let g = store.game else { return }
                g.fillNotes()
                g.selected = g.values.firstIndex(of: 0)
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
