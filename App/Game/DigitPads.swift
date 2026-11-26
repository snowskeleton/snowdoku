import SwiftUI
import SudokuCore

/// The digit pads. Two pads: big digits (values) and small digits (notes). One pad: a single set of
/// digits plus a Digits / Notes / Center switch. With a cell selected they enter into it; with none selected,
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

    /// One set of digits with the mode keys as a fourth column (or, when wide, three more keys at the
    /// end of the row), all the same size. Keys keep one height in every mode so nothing jumps, and
    /// skip the remaining counts.
    var onePad: some View {
        let small = game.padMode != .digits, centered = game.padMode == .centerNotes
        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                ForEach(1...9, id: \.self) { d in
                    DigitKey(game: game, digit: d, small: small, height: rowKeyHeight, centered: centered, showsRemaining: false)
                }
                Color.clear.frame(width: 6, height: 1)
                ForEach(PadMode.allCases, id: \.self) { modeKey($0, height: rowKeyHeight) }
            }
            .frame(minWidth: 600)
            Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                ForEach(0..<3, id: \.self) { r in
                    GridRow {
                        ForEach(1...3, id: \.self) { k in
                            DigitKey(game: game, digit: r * 3 + k, small: small, height: gridKeyHeight, centered: centered, showsRemaining: false)
                        }
                        modeKey(PadMode.allCases[r], height: gridKeyHeight)
                    }
                }
            }
        }
    }

    /// A key of the Digits / Notes / Center switch.
    func modeKey(_ m: PadMode, height: Double) -> some View {
        ModeKey(title: m.title, mode: m, on: game.padMode == m, height: height) { game.choosePadMode(m) }
    }

    func row(small: Bool, centered: Bool = false) -> some View {
        HStack(spacing: 6) {
            ForEach(1...9, id: \.self) { d in
                DigitKey(game: game, digit: d, small: small, height: small ? noteRowKeyHeight : rowKeyHeight, centered: centered)
            }
        }
    }

    func grid(small: Bool, centered: Bool = false) -> some View {
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(0..<3, id: \.self) { r in
                GridRow {
                    ForEach(1...3, id: \.self) { k in
                        DigitKey(game: game, digit: r * 3 + k, small: small, height: gridKeyHeight, centered: centered)
                    }
                }
            }
        }
    }
}
