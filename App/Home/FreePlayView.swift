import SwiftUI
import SudokuCore

/// Random games by tier, each tier keeping its own unfinished game.
struct FreePlayView: View {
    @Environment(GameStore.self) private var store
    /// The tier whose "Continue or new game?" question is showing.
    @State private var choosing: Difficulty?

    var body: some View {
        List {
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
        .navigationTitle("Free Play")
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

    func startNewGame(_ difficulty: Difficulty) {
        Task { await store.newGame(difficulty) }
    }
}
