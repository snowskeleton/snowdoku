import SwiftUI

/// A game action (Undo, Fill, Hint) drawn as a pad key, for the one-pad layout's last column.
struct ActionKey: View {
    let title: String
    let systemImage: String
    let height: Double
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2)
                .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
                .opacity(isEnabled ? 1 : 0.35)
        }
        .buttonStyle(PadKeyStyle(armed: false, small: false, finished: false))
        .accessibilityLabel(title)
    }
}
