import SwiftUI

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
