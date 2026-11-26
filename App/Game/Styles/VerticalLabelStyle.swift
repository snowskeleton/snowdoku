import SwiftUI

/// Icon above title, for the controls row under the board.
struct VerticalLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(spacing: 4) {
            configuration.icon.font(.title2)
            configuration.title.font(.caption)
        }
    }
}
