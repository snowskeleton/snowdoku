import SwiftUI
import SudokuCore

/// Two digit pads: big digits (values) and small digits (notes). With a cell selected they enter
/// into it; with none selected, tapping arms a digit to apply to many cells.
/// Wide spaces get two single rows; narrower ones get two 3x3 grids side by side.
struct DigitPads: View {
    @Bindable var game: Game
    @ScaledMetric private var rowKeyHeight = 56.0
    @ScaledMetric private var noteRowKeyHeight = 44.0
    @ScaledMetric private var gridKeyHeight = 48.0

    var body: some View {
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
        .disabled(game.isComplete)
        // Past this size the pads would squeeze the board too much.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
