import SwiftUI
import SudokuCore

/// A real position from the drill bank with the technique's move drawn on the board,
/// the way a hint shows it at the answer level, plus its explanation.
struct TechniqueExample: View {
    let drill: Drill
    @State private var example: (game: Game, step: Step)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let example {
                BoardView(game: example.game)
                    .allowsHitTesting(false)
                    .frame(maxWidth: 420)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
                Text(example.step.explanation)
                    .font(.subheadline)
            } else {
                ProgressView().frame(maxWidth: .infinity, minHeight: 200)
            }
        }
        .padding(.vertical, 4)
        .task(id: drill) { await load() }
    }

    func load() async {
        let d = drill
        let found = await Task.detached(priority: .userInitiated) { () -> (SudokuCore.Grid, Step)? in
            guard let solution = BruteForce.solution(d.puzzle), let step = d.step() else { return nil }
            return (solution, step)
        }.value
        guard let (solution, step) = found else { return }
        let game = Game(drill: d, solution: solution, tracking: false)
        game.pauseClock()
        game.hint = HintSession(hint: .step(step), level: .answer)
        example = (game, step)
    }
}
