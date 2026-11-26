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

/// A digit pad key. Uses system fills so pressed, disabled and dark mode come for free.
struct PadKeyStyle: ButtonStyle {
    var armed: Bool
    var small: Bool
    /// All nine of this digit are placed.
    var finished: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(foreground)
            .background(background(pressed: configuration.isPressed), in: .rect(cornerRadius: 10))
            .contentShape(.rect)
    }

    var foreground: AnyShapeStyle {
        if armed { AnyShapeStyle(.white) }
        else if finished { AnyShapeStyle(.tertiary) }
        else if small { AnyShapeStyle(.secondary) }
        else { AnyShapeStyle(.primary) }
    }

    func background(pressed: Bool) -> AnyShapeStyle {
        if armed { AnyShapeStyle(Color.accentColor) }
        else if pressed { AnyShapeStyle(.fill.secondary) }
        else { AnyShapeStyle(.fill.tertiary) }
    }
}
