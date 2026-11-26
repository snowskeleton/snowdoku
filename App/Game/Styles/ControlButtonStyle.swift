import SwiftUI

/// Borderless control (Undo, Erase…): full-width hit area, system dimming when pressed or disabled.
struct ControlButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        ControlButton(configuration: configuration)
    }

    private struct ControlButton: View {
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .frame(maxWidth: .infinity, minHeight: 50)
                .contentShape(.rect)
                .foregroundStyle(isEnabled ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary))
                .opacity(configuration.isPressed ? 0.5 : 1)
        }
    }
}
