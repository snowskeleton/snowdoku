import SwiftUI

/// One side of the one-pad layout's Digits / Notes / Center switch, styled like a pad key.
/// Its icon is a little cell showing what the mode enters: a big 1, grid notes 2 3 4, or centered 58.
struct ModeKey: View {
    let title: String
    let mode: PadMode
    let on: Bool
    let action: () -> Void
    @ScaledMetric(relativeTo: .title2) private var side = 22.0

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                icon
                    .frame(width: side, height: side)
                    .overlay(RoundedRectangle(cornerRadius: side * 0.18).strokeBorder(.secondary.opacity(0.6), lineWidth: 1))
                Text(title).font(.caption)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(PadKeyStyle(armed: on, small: false, finished: false))
        .accessibilityLabel(title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    @ViewBuilder var icon: some View {
        let font = Font.system(size: side * 0.3, weight: .semibold, design: .rounded)
        switch mode {
        case .digits:
            Text("1").font(.system(size: side * 0.72, weight: .medium, design: .rounded))
        case .notes:
            // 2, 3 and 4 in their spots of the cell's 3x3 grid.
            ZStack {
                Text("2").frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                Text("3").frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                Text("4").frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .font(font)
            .padding(.horizontal, side * 0.12)
            .padding(.vertical, side * 0.04)
        case .centerNotes:
            Text("58").font(font)
        }
    }
}
