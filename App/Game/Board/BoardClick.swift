import SwiftUI

/// A tap or click on the board, reported at its location in the view's own space, with whether Shift
/// was held. `secondary` listens for right-clicks instead. SwiftUI's tap gesture reports neither
/// modifiers nor buttons, so this wraps the platform recognizer. (The Mac reads Shift from NSEvent in
/// a plain SwiftUI tap and uses this only for right-clicks.)
#if os(iOS)
struct BoardClick: UIGestureRecognizerRepresentable {
    var secondary = false
    let action: (CGPoint, _ shift: Bool) -> Void

    func makeUIGestureRecognizer(context: Context) -> UITapGestureRecognizer {
        let g = UITapGestureRecognizer()
        g.buttonMaskRequired = secondary ? .secondary : .primary
        return g
    }

    func handleUIGestureRecognizerAction(_ g: UITapGestureRecognizer, context: Context) {
        if g.state == .ended { action(context.converter.localLocation, g.modifierFlags.contains(.shift)) }
    }
}
#else
struct BoardClick: NSGestureRecognizerRepresentable {
    var secondary = false
    let action: (CGPoint, _ shift: Bool) -> Void

    func makeNSGestureRecognizer(context: Context) -> NSClickGestureRecognizer {
        let g = NSClickGestureRecognizer()
        g.buttonMask = secondary ? 0x2 : 0x1
        return g
    }

    func handleNSGestureRecognizerAction(_ g: NSClickGestureRecognizer, context: Context) {
        if g.state == .ended { action(context.converter.localLocation, NSEvent.modifierFlags.contains(.shift)) }
    }
}
#endif

/// Right-clicks on the board. Attaching an AppKit recognizer needs macOS 26; earlier Macs go without.
struct RightClick: ViewModifier {
    let action: (CGPoint) -> Void

    func body(content: Content) -> some View {
        #if os(iOS)
        content.gesture(BoardClick(secondary: true) { p, _ in action(p) })
        #else
        if #available(macOS 26, *) {
            content.gesture(BoardClick(secondary: true) { p, _ in action(p) })
        } else {
            content
        }
        #endif
    }
}
