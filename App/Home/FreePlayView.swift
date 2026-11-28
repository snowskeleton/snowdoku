import SwiftUI
import SudokuCore

/// Random games: pick a tier, then a level within it (Extreme has no levels, so it starts right
/// away). Each tier keeps its own unfinished game.
struct FreePlayView: View {
    @Environment(GameStore.self) private var store
    @State private var newGame = NewGameChoice()

    var body: some View {
        List {
            ForEach(GameStore.playable, id: \.self) { d in
                if Level.levels(in: d).count > 1 {
                    NavigationLink(value: PlayRoute.freePlayTier(d)) { row(d) }
                        .accessibilityIdentifier("tier.\(d.name)")
                } else {
                    Button { newGame.tap(Level.first(in: d), store: store) } label: { row(d) }
                        .accessibilityIdentifier("tier.\(d.name)")
                }
            }
        }
        .navigationTitle("Free Play")
        .onAppear(perform: store.reloadSaved)
        .newGameDialog($newGame, store: store)
    }

    func row(_ d: Difficulty) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading) {
                Text(d.name).font(.headline)
                Text(subtitle(d)).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer(minLength: 8)
            if let s = store.savedGame(.random(d)) {
                Text("In progress · \(formatTime(s.record.elapsed))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    func subtitle(_ d: Difficulty) -> String {
        let n = Level.levels(in: d).count
        let blurb = Technique.tierBlurbs[d] ?? ""
        return n > 1 ? "\(n) levels · \(blurb)" : blurb
    }
}

/// The levels of one tier. Each adds a few techniques to everything below it.
struct FreePlayLevelsView: View {
    let tier: Difficulty
    @Environment(GameStore.self) private var store
    @State private var newGame = NewGameChoice()

    var body: some View {
        List {
            Section {
                ForEach(GameStore.playableLevels(tier), id: \.self) { l in
                    Button { newGame.tap(l, store: store) } label: {
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading) {
                                Text(l.name).font(.headline)
                                Text("Adds \(l.blurb)").font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                            Spacer(minLength: 8)
                            if let s = store.savedGame(.random(tier)), s.record.level == l {
                                Text("In progress · \(formatTime(s.record.elapsed))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .accessibilityIdentifier("level.\(l.rawValue)")
                }
            } footer: {
                Text("Each level uses the techniques of every level before it.")
            }
        }
        .navigationTitle(tier.name)
        .onAppear(perform: store.reloadSaved)
        .newGameDialog($newGame, store: store)
    }
}

/// Starting a random game at a level, asking first when its tier has an unfinished game (which
/// a new game replaces).
struct NewGameChoice {
    /// The level whose "Continue or new game?" question is showing.
    var asking: Level?

    @MainActor mutating func tap(_ level: Level, store: GameStore) {
        if store.savedGame(.random(level.tier)) != nil { asking = level } else { Self.start(level, store: store) }
    }

    @MainActor static func start(_ level: Level, store: GameStore) {
        Task { await store.newGame(level) }
    }
}

extension View {
    func newGameDialog(_ choice: Binding<NewGameChoice>, store: GameStore) -> some View {
        confirmationDialog("Continue or new game?", isPresented: Binding { choice.wrappedValue.asking != nil } set: { if !$0 { choice.wrappedValue.asking = nil } },
                           titleVisibility: .visible, presenting: choice.wrappedValue.asking) { l in
            Button("Continue") { store.continueGame(.random(l.tier)) }
            Button("New \(l.name) game", role: .destructive) { NewGameChoice.start(l, store: store) }
            Button("Cancel", role: .cancel) {}
        } message: { l in
            if let s = store.savedGame(.random(l.tier)) {
                Text("You have a \(s.title) game in progress (\(formatTime(s.record.elapsed))). A new game replaces it.")
            }
        }
    }
}
