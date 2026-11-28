import SwiftUI

/// Controls and pads. The hint panel, drill result and Finish pill float over them so nothing moves when they
/// appear. The hint panel sits on the controls row and grows upward over the board, never over the pads, so
/// the player can act on the hint while it stays open. With one pad (no controls row) it sits just above the pad.
struct GameInputArea: View {
    @Bindable var game: Game
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("padLayout") private var padLayout: PadLayout = .twoPads

    var body: some View {
        VStack(spacing: 12) {
            // One pad carries its own Undo / Fill / Hint keys.
            if padLayout == .twoPads {
                ControlsView(game: game)
                    .overlay(alignment: .bottom) { hintPanel }
            }
            DigitPads(game: game)
                .overlay(alignment: .top) {
                    if padLayout == .onePad {
                        // A zero-height anchor on the pad's top edge; the panel's bottom sits just above it.
                        Color.clear.frame(height: 0)
                            .overlay(alignment: .bottom) { hintPanel.padding(.bottom, 8) }
                    }
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
        .animation(.spring(duration: 0.3), value: game.coach)
    }

    /// Taller than its anchor, so it overflows upward from the anchor's bottom edge.
    @ViewBuilder var hintPanel: some View {
        if game.hint != nil {
            HintPanel(game: game)
                .fixedSize(horizontal: false, vertical: true)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        } else if game.coach != nil && game.spotlightActive {
            CoachPanel(game: game)
                .fixedSize(horizontal: false, vertical: true)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        }
    }

    func finish() {
        Task { await game.autoComplete(animated: !reduceMotion) }
    }
}
