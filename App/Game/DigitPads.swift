import SwiftUI
import SudokuCore

/// The digit pads. Two pads: big digits (values) and small digits (notes). One pad: a single set of
/// digits plus a Digits / Notes switch. With a cell selected they enter into it; with none selected,
/// tapping arms a digit to apply to many cells.
/// Wide spaces get single rows; narrower ones get 3x3 grids side by side.
struct DigitPads: View {
    @Bindable var game: Game
    @AppStorage("padLayout") private var layout: PadLayout = .twoPads
    @ScaledMetric private var rowKeyHeight = 56.0
    @ScaledMetric private var noteRowKeyHeight = 44.0
    @ScaledMetric private var gridKeyHeight = 48.0

    var body: some View {
        Group {
            switch layout {
            case .twoPads: twoPads
            case .onePad: onePad
            }
        }
        .disabled(game.isComplete)
        // Past this size the pads would squeeze the board too much.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    var twoPads: some View {
        ViewThatFits(in: .horizontal) {
            VStack(spacing: 8) {
                row(small: false)
                row(small: true)
            }
            .frame(minWidth: 600)
            HStack(spacing: 14) {
                grid(small: false)
                grid(small: true)
            }
        }
    }

    var onePad: some View {
        ViewThatFits(in: .horizontal) {
            VStack(spacing: 8) {
                row(small: game.noteMode)
                HStack(spacing: 6) { modeKeys }
                    .frame(height: noteRowKeyHeight)
            }
            .frame(minWidth: 600)
            HStack(spacing: 14) {
                grid(small: game.noteMode)
                VStack(spacing: 6) { modeKeys }
                    .frame(maxWidth: 110)
                    // As tall as the three rows of digits beside it.
                    .frame(height: gridKeyHeight * 3 + 12)
            }
        }
    }

    /// The Digits / Notes switch of the one-pad layout.
    @ViewBuilder var modeKeys: some View {
        ModeKey(title: "Digits", systemImage: "textformat.123", on: !game.noteMode) { game.noteMode = false }
        ModeKey(title: "Notes", systemImage: "pencil", on: game.noteMode) { game.noteMode = true }
    }

    func row(small: Bool) -> some View {
        HStack(spacing: 6) {
            ForEach(1...9, id: \.self) { d in DigitKey(game: game, digit: d, small: small, height: small ? noteRowKeyHeight : rowKeyHeight) }
        }
    }

    func grid(small: Bool) -> some View {
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(0..<3, id: \.self) { r in
                GridRow {
                    ForEach(1...3, id: \.self) { k in DigitKey(game: game, digit: r * 3 + k, small: small, height: gridKeyHeight) }
                }
            }
        }
    }
}
