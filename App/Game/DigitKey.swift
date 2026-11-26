import SwiftUI
import SudokuCore

struct DigitKey: View {
    @Bindable var game: Game
    let digit: Int
    let small: Bool
    let height: Double
    /// A centered-note key (one-pad Center mode): the digit sits in the middle.
    var centered = false
    @ScaledMetric(relativeTo: .title) private var digitSize = 28.0
    @ScaledMetric(relativeTo: .body) private var noteSize = 15.0

    var body: some View {
        let left = game.remaining(digit)
        let armed = game.armed == ArmedDigit(digit: digit, small: small, centered: small && centered)
        Button { game.tapDigit(digit, small: small, centered: centered) } label: {
            ZStack(alignment: small ? notePosition : .center) {
                Color.clear
                if small {
                    Text("\(digit)")
                        .font(.system(size: noteSize, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 8).padding(.vertical, 5)
                } else {
                    VStack(spacing: 0) {
                        Text("\(digit)").font(.system(size: digitSize, weight: .medium, design: .rounded))
                        if left > 0 { Text("\(left)").font(.caption2).foregroundStyle(.secondary) }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        }
        .buttonStyle(PadKeyStyle(armed: armed, small: small, finished: !small && left == 0))
        .accessibilityLabel(small ? "\(centered ? "Center note" : "Note") \(digit)" : "\(digit), \(left) remaining")
        .accessibilityAddTraits(armed ? .isSelected : [])
    }

    /// Small digits sit where they'd appear in a cell's notes.
    var notePosition: Alignment {
        if centered { return .center }
        let i = digit - 1
        let h: [HorizontalAlignment] = [.leading, .center, .trailing]
        let v: [VerticalAlignment] = [.top, .center, .bottom]
        return Alignment(horizontal: h[i % 3], vertical: v[i / 3])
    }
}
