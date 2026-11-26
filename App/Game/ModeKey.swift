import SwiftUI

/// One key of the one-pad layout's Digits / Notes / Center switch, the size of a digit key.
/// It shows what the mode enters, drawn like the pad's own keys: a big 1, small 2 3 4 in their
/// grid spots, or a small 58 in the middle.
struct ModeKey: View {
    let title: String
    let mode: PadMode
    let on: Bool
    let height: Double
    let action: () -> Void
    @ScaledMetric(relativeTo: .title) private var digitSize = 28.0
    @ScaledMetric(relativeTo: .body) private var noteSize = 15.0

    var body: some View {
        Button(action: action) {
            icon
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        }
        .buttonStyle(PadKeyStyle(armed: on, small: false, finished: false))
        .accessibilityLabel(title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    @ViewBuilder var icon: some View {
        let note = Font.system(size: noteSize, weight: .semibold, design: .rounded)
        switch mode {
        case .digits:
            Text("1").font(.system(size: digitSize, weight: .medium, design: .rounded))
        case .notes:
            // Same spots and padding as the small keys' digits.
            ZStack {
                Text("2").frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                Text("3").frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                Text("4").frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .font(note)
            .padding(.horizontal, 8).padding(.vertical, 5)
        case .centerNotes:
            Text("58").font(note)
        }
    }
}
