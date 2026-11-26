import SwiftUI

/// One side of the one-pad layout's Digits / Notes switch, styled like a pad key.
struct ModeKey: View {
    let title: String
    let systemImage: String
    let on: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .labelStyle(VerticalLabelStyle())
                .font(.callout.weight(.medium))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(PadKeyStyle(armed: on, small: false, finished: false))
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}
