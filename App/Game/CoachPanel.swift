import SwiftUI
import SudokuCore

/// Floats over the controls during a spotlight question: what the question practices, or why the
/// last move wasn't the answer. Like the hint panel, it never moves the board.
struct CoachPanel: View {
    let game: Game

    var body: some View {
        if let coach = game.coach {
            HStack(alignment: .top) {
                icon(coach)
                Text(coach.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("coachText")
                Spacer(minLength: 0)
                Button("Close", systemImage: "xmark", action: close)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(.rect)
                    .padding(-12)
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .strokeBorder(Color.primary.opacity(0.08))
            }
            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
            .id(game.attempts) // a new bounce replaces the card visibly, even with the same text
        }
    }

    @ViewBuilder func icon(_ c: Coach) -> some View {
        switch c {
        case .intro:
            Image(systemName: "graduationcap.fill").foregroundStyle(Color.accentColor)
        case .feedback(.conflict, _), .feedback(.wrong, _):
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        case .feedback:
            Image(systemName: "checkmark.circle").foregroundStyle(.orange)
        }
    }

    func close() { withAnimation { game.coach = nil } }
}
