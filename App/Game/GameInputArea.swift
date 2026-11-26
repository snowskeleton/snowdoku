import SwiftUI

/// Controls and pads. The hint panel, drill result and Finish pill float over them (never over the board,
/// whose highlights the hint refers to) so nothing moves when they appear.
struct GameInputArea: View {
    @Bindable var game: Game
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("padLayout") private var padLayout: PadLayout = .twoPads

    var body: some View {
        VStack(spacing: 12) {
            // One pad carries its own Undo / Fill / Hint keys.
            if padLayout == .twoPads { ControlsView(game: game) }
            DigitPads(game: game)
        }
        .overlay(alignment: .bottom) {
            if game.hint != nil {
                HintPanel(game: game)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .bottom) {
            if game.drillState == .found && game.drill != nil && game.hint == nil && !game.isComplete {
                DrillPanel(game: game)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) {
            if game.canAutoComplete && game.hint == nil {
                Button("Finish puzzle", systemImage: "wand.and.stars", action: finish)
                    .font(.headline)
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .controlSize(.large)
                    .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
                    // Float just above the controls row, never over the buttons.
                    .offset(y: -54)
                    .transition(reduceMotion ? .opacity : .scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: game.canAutoComplete)
        .animation(.spring(duration: 0.3), value: game.drillState)
    }

    func finish() {
        Task { await game.autoComplete(animated: !reduceMotion) }
    }
}
