import SwiftUI
import SudokuCore

struct NotesView: View {
    let game: Game
    let cell: Int
    let ctx: BoardContext
    let size: CGFloat
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        let notes = game.notes[cell]
        let roles = ctx.hintRoles[cell] ?? [:]
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(1...3, id: \.self) { k in
                        let d = r * 3 + k
                        let cand = Candidate(cell, d)
                        let shown = notes & Mask.bit(d) != 0 || roles[d] != nil || ctx.hintElims.contains(cand) || ctx.hintMissing.contains(cand)
                        Text(shown ? "\(d)" : " ")
                            .font(.system(size: size * 0.27, weight: noteWeight(d, roles), design: .rounded))
                            .strikethrough(ctx.hintElims.contains(cand), color: .red)
                            // Restored notes are green; underline them too when color can't be relied on.
                            .underline(differentiateWithoutColor && ctx.hintMissing.contains(cand), color: .green)
                            .foregroundStyle(noteColor(d, roles, cand))
                            .frame(width: size / 3, height: size / 3)
                            .background(noteBackground(d, roles, cand), in: RoundedRectangle(cornerRadius: size * 0.06))
                    }
                }
            }
        }
    }

    func noteWeight(_ d: Int, _ roles: [Int: Highlight.Role]) -> Font.Weight {
        (roles[d] != nil || (ctx.highlightSame && d == ctx.highlightDigit)) ? .heavy : .regular
    }

    func noteColor(_ d: Int, _ roles: [Int: Highlight.Role], _ cand: Candidate) -> Color {
        if ctx.hintElims.contains(cand) { return .red }
        if ctx.hintMissing.contains(cand) { return .green }
        if roles[d] != nil { return .primary }
        if ctx.highlightSame && d == ctx.highlightDigit { return .accentColor }
        return .secondary
    }

    func noteBackground(_ d: Int, _ roles: [Int: Highlight.Role], _ cand: Candidate) -> Color {
        if let role = roles[d] { return role.color.opacity(0.45) }
        return .clear
    }
}
