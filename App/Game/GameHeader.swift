import SwiftUI
import SudokuCore

/// Difficulty, mistake count and timer above the board; in a drill, what to look for.
struct GameHeader: View {
    let game: Game
    @AppStorage("showTimer") private var showTimer = true
    @AppStorage("mistakeMode") private var mistakeMode: MistakeMode = .conflicts

    var body: some View {
        HStack {
            if let drill = game.drill {
                Label(drillPrompt(drill), systemImage: game.drillState == .searching ? "scope" : "checkmark.circle.fill")
                    .foregroundStyle(game.drillState == .searching ? Color.primary : Color.green)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
            } else {
                Label(game.difficulty.name, systemImage: "chart.bar.fill")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            if mistakeMode == .solution {
                Label("\(game.mistakes)", systemImage: "xmark.circle")
                    .foregroundStyle(game.mistakes > 0 ? .red : .secondary)
            }
            if showTimer && game.drill == nil {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text(formatTime(game.elapsed(at: ctx.date)))
                        .monospacedDigit()
                }
                .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
    }

    func drillPrompt(_ d: Drill) -> String {
        game.drillState == .searching ? "Find the next move: \(d.technique.name)" : "Found: \(d.technique.name)"
    }
}
