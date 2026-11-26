import SwiftUI
import SudokuCore

struct CellView: View {
    let game: Game
    let cell: Int
    let ctx: BoardContext
    let size: CGFloat
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        let v = game.value(cell)
        ZStack {
            Rectangle().fill(background(v))
            // A flash (a completed digit, an auto-completed cell) snaps on and fades slowly.
            Rectangle()
                .fill(Color.accentColor)
                .keyframeAnimator(initialValue: 0.0, trigger: game.flashes[cell]) { content, glow in
                    content.opacity(glow)
                } keyframes: { _ in
                    LinearKeyframe(0.45, duration: 0.08)
                    CubicKeyframe(0.45, duration: 0.15)
                    CubicKeyframe(0, duration: 1.1)
                }
                .allowsHitTesting(false)
            if v != 0 {
                Text("\(v)")
                    .font(.system(size: size * 0.62, weight: game.isGiven(cell) ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(valueColor(v))
            } else {
                NotesView(game: game, cell: cell, ctx: ctx, size: size)
            }
        }
        // Red alone marks a mistake; with Differentiate Without Color, add a shape too.
        .overlay(alignment: .topTrailing) {
            if differentiateWithoutColor && isMarkedWrong {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: size * 0.22))
                    .foregroundStyle(.red)
                    .padding(size * 0.05)
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityText(v))
        .accessibilityAddTraits(ctx.selected == cell ? [.isSelected, .isButton] : .isButton)
        .accessibilityAction { game.tapCell(cell) }
    }

    func background(_ v: Int) -> Color {
        if ctx.hintWrong.contains(cell) { return .red.opacity(0.35) }
        if ctx.hintPlacements.contains(where: { $0.cell == cell }) { return .green.opacity(0.35) }
        if let roles = ctx.hintRoles[cell], roles[0] != nil { return .yellow.opacity(0.35) }
        if ctx.selected == cell { return .accentColor.opacity(0.38) }
        if ctx.conflicts.contains(cell) { return .red.opacity(0.18) }
        if ctx.highlightSame && ctx.highlightDigit != 0 {
            if v == ctx.highlightDigit { return .accentColor.opacity(0.28) }
            if v == 0 && game.notes[cell] & Mask.bit(ctx.highlightDigit) != 0 { return .accentColor.opacity(0.16) }
        }
        if ctx.hintHouses.contains(cell) { return .yellow.opacity(0.16) }
        if ctx.highlightPeers && ctx.peers.contains(cell) { return .accentColor.opacity(0.08) }
        return .clear
    }

    /// Shown in red: a conflicting or wrong entry, or a cell a hint flagged as wrong.
    var isMarkedWrong: Bool {
        if ctx.hintWrong.contains(cell) { return true }
        guard game.value(cell) != 0, !game.isGiven(cell) else { return false }
        return switch ctx.mistakeMode {
        case .solution: game.isWrong(cell)
        case .conflicts: ctx.conflicts.contains(cell)
        case .off: false
        }
    }

    func valueColor(_ v: Int) -> Color {
        if game.isGiven(cell) { return .primary }
        return isMarkedWrong ? .red : .accentColor
    }

    func accessibilityText(_ v: Int) -> String {
        let pos = "Row \(cell / 9 + 1), column \(cell % 9 + 1)"
        if v != 0 { return "\(pos), \(v)\(game.isGiven(cell) ? ", given" : "")\(isMarkedWrong ? ", mistake" : "")" }
        let n = Mask.digits(game.notes[cell])
        let kind = game.drawsCentered(cell) ? "centered notes" : "notes"
        return n.isEmpty ? "\(pos), empty" : "\(pos), \(kind) \(n.map(String.init).joined(separator: " "))"
    }
}
