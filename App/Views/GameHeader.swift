import SwiftUI

/// Difficulty, mistake count and timer above the board.
struct GameHeader: View {
    let game: Game
    @AppStorage("showTimer") private var showTimer = true
    @AppStorage("mistakeMode") private var mistakeMode: MistakeMode = .conflicts

    var body: some View {
        HStack {
            Label(game.difficulty.name, systemImage: "chart.bar.fill")
                .foregroundStyle(.secondary)
            Spacer()
            if mistakeMode == .solution {
                Label("\(game.mistakes)", systemImage: "xmark.circle")
                    .foregroundStyle(game.mistakes > 0 ? .red : .secondary)
            }
            if showTimer {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text(formatTime(game.elapsed(at: ctx.date)))
                        .monospacedDigit()
                }
                .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
    }
}
