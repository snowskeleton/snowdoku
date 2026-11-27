import SwiftUI
import SudokuCore

struct CellView: View {
    let game: Game
    let cell: Int
    let ctx: BoardContext
    let size: CGFloat
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let v = game.value(cell)
        ZStack {
            Rectangle().fill(background(v))
            // The selected cell gets an outline too, so it stands out from same-digit tints.
            if ctx.isSelected(cell) {
                Rectangle()
                    .strokeBorder(Color.accentColor, lineWidth: max(2, size * 0.05))
                    .allowsHitTesting(false)
            }
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
        .accessibilityAddTraits(ctx.isSelected(cell) ? [.isSelected, .isButton] : .isButton)
        .accessibilityAction { game.tapCell(cell) }
    }

    func background(_ v: Int) -> Color {
        let t = CellTint(colorScheme: colorScheme, contrast: contrast)
        if ctx.hintWrong.contains(cell) { return .red.opacity(t.hint) }
        if ctx.hintPlacements.contains(where: { $0.cell == cell }) { return .green.opacity(t.hint) }
        if let roles = ctx.hintRoles[cell], roles[0] != nil { return .yellow.opacity(t.hint) }
        if ctx.isSelected(cell) && !ctx.hintOnBoard { return .accentColor.opacity(t.selected) }
        if ctx.conflicts.contains(cell) { return .red.opacity(t.conflict) }
        if ctx.highlightSame && ctx.highlightDigit != 0 {
            if v == ctx.highlightDigit { return .accentColor.opacity(t.sameDigit) }
            if v == 0 && game.notes[cell] & Mask.bit(ctx.highlightDigit) != 0 { return .accentColor.opacity(t.noteDigit) }
        }
        if ctx.hintHouses.contains(cell) { return .yellow.opacity(t.hintHouse) }
        if ctx.highlightPeers && ctx.peers.contains(cell) { return .accentColor.opacity(t.peer) }
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
