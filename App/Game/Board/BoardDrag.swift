import SwiftUI

/// A drag across the board, in board-local points. `changed` reports where the drag started (the
/// touch-down point, not where it was recognized), where it is now, and whether Shift is held;
/// `ended` follows when it finishes or is cancelled. Taps never trigger it, so it sits beside the
/// board's tap handler. It is always on, even when a drag has nothing to apply, so a drag on the
/// board never becomes the system's swipe back out of the game. iOS wraps UIPanGestureRecognizer for the modifier flags; the Mac uses a
/// SwiftUI drag and reads Shift from NSEvent.
enum BoardDragEvent {
    case changed(start: CGPoint, location: CGPoint, shift: Bool)
    case ended
}

#if os(iOS)
struct BoardDrag: UIGestureRecognizerRepresentable {
    let action: (BoardDragEvent) -> Void

    /// Remembers where the touch went down. The pan's own translation starts where it was
    /// recognized, which on a quick stroke is already a cell or more away.
    final class Recognizer: UIPanGestureRecognizer {
        var touchDown: CGPoint?

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
            if numberOfTouches == 0 { touchDown = touches.first?.location(in: view) }
            super.touchesBegan(touches, with: event)
        }
    }

    func makeUIGestureRecognizer(context: Context) -> Recognizer {
        let g = Recognizer()
        g.maximumNumberOfTouches = 1
        return g
    }

    func handleUIGestureRecognizerAction(_ g: Recognizer, context: Context) {
        switch g.state {
        case .began, .changed, .ended:
            let p = context.converter.localLocation
            // The view's space and the board's differ only by an offset.
            let now = g.location(in: g.view)
            let down = g.touchDown ?? now
            action(.changed(start: CGPoint(x: p.x - (now.x - down.x), y: p.y - (now.y - down.y)), location: p,
                            shift: g.modifierFlags.contains(.shift)))
            // A quick stroke's last stretch arrives only with the end.
            if g.state == .ended { action(.ended) }
        case .cancelled, .failed:
            action(.ended)
        default:
            break
        }
    }
}
#endif

extension View {
    /// Reports drags on this view as `BoardDragEvent`s.
    @ViewBuilder
    func boardDrag(_ action: @escaping (BoardDragEvent) -> Void) -> some View {
        #if os(iOS)
        gesture(BoardDrag(action: action))
        #else
        simultaneousGesture(
            DragGesture(minimumDistance: 4, coordinateSpace: .local)
                .onChanged { v in
                    action(.changed(start: v.startLocation, location: v.location,
                                    shift: NSEvent.modifierFlags.contains(.shift)))
                }
                .onEnded { _ in action(.ended) })
        #endif
    }
}
