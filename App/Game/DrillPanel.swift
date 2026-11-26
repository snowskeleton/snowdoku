import SwiftUI
import SudokuCore

/// Floats over the controls once the player makes the drill's move.
struct DrillPanel: View {
    let game: Game
    @Environment(GameStore.self) private var store

    var body: some View {
        if let drill = game.drill {
            VStack(alignment: .leading, spacing: 10) {
                Label("That's the \(drill.technique.name)!", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                if let step = game.drillFoundStep {
                    Text(step.explanation)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Button("Keep solving", action: keepSolving)
                        .buttonStyle(.bordered)
                    Spacer()
                    Button("Next drill", action: nextDrill)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .strokeBorder(Color.primary.opacity(0.08))
            }
            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        }
    }

    func keepSolving() {
        withAnimation { game.drillState = .dismissed }
        store.save()
    }

    func nextDrill() {
        guard let t = game.drill?.technique else { return }
        Task { await store.drill(t) }
    }
}
