import SwiftUI
import SudokuCore

struct CompletionView: View {
    let game: Game
    @Environment(GameStore.self) private var store

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 48)).foregroundStyle(.green)
            Text("Solved!").font(.largeTitle.bold())
            Text("\(game.difficulty.name) · \(formatTime(game.elapsed()))")
                .foregroundStyle(.secondary)
            if game.hintsUsed > 0 || game.mistakes > 0 {
                Text("^[\(game.hintsUsed) hint](inflect: true) · ^[\(game.mistakes) mistake](inflect: true)")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if !advancedTechniques.isEmpty {
                Text("Techniques: \(advancedTechniques.map(\.name).formatted())")
                    .font(.footnote).multilineTextAlignment(.center).foregroundStyle(.secondary)
            }
            HStack {
                Button("Home", action: store.leaveGame).buttonStyle(.bordered)
                Button(game.drill == nil ? "Next puzzle" : "Next drill", action: nextPuzzle).buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding()
    }

    /// Techniques worth calling out (every puzzle uses singles).
    var advancedTechniques: [Technique] {
        game.techniques.filter { $0.difficulty > .beginner }
    }

    func nextPuzzle() {
        if let t = game.drill?.technique {
            Task { await store.drill(t) }
            return
        }
        let d = game.difficulty
        Task { await store.newGame(GameStore.playable.contains(d) ? d : .master) }
    }
}
