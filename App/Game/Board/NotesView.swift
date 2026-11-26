import SwiftUI
import SudokuCore

struct NotesView: View {
    let game: Game
    let cell: Int
    let ctx: BoardContext
    let size: CGFloat
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @AppStorage("noteStyle") private var noteStyle: NoteStyle = .grid

    var body: some View {
        switch noteStyle {
        case .grid: grid
        case .center: centered
        }
    }

    /// Each digit in its own spot: 1 top left … 9 bottom right.
    var grid: some View {
        VStack(spacing: 0) {
            ForEach(0..<3, id: \.self) { r in
                HStack(spacing: 0) {
                    ForEach(1...3, id: \.self) { k in
                        let d = r * 3 + k
                        note(d, shown: isShown(d), fontSize: size * 0.27)
                    }
                }
            }
        }
    }

    /// The shown digits side by side in the middle, on two lines past five.
    var centered: some View {
        let digits = (1...9).filter(isShown)
        let lines = digits.count > 5 ? [Array(digits.prefix((digits.count + 1) / 2)), Array(digits.dropFirst((digits.count + 1) / 2))] : [digits]
        let fontSize = size * (digits.count > 5 ? 0.22 : digits.count > 3 ? 0.24 : 0.28)
        return VStack(spacing: 0) {
            ForEach(lines.indices, id: \.self) { i in
                HStack(spacing: size * 0.01) {
                    ForEach(lines[i], id: \.self) { d in note(d, shown: true, fontSize: fontSize) }
                }
            }
        }
        .frame(width: size, height: size)
    }

    func isShown(_ d: Int) -> Bool {
        let cand = Candidate(cell, d)
        return game.notes[cell] & Mask.bit(d) != 0 || roles[d] != nil || ctx.hintElims.contains(cand) || ctx.hintMissing.contains(cand)
    }

    var roles: [Int: Highlight.Role] { ctx.hintRoles[cell] ?? [:] }

    func note(_ d: Int, shown: Bool, fontSize: CGFloat) -> some View {
        let cand = Candidate(cell, d)
        let roles = roles
        return Text(shown ? "\(d)" : " ")
            .font(.system(size: fontSize, weight: noteWeight(d, roles), design: .rounded))
            .strikethrough(ctx.hintElims.contains(cand), color: .red)
            // Restored notes are green; underline them too when color can't be relied on.
            .underline(differentiateWithoutColor && ctx.hintMissing.contains(cand), color: .green)
            .foregroundStyle(noteColor(d, roles, cand))
            // A grid note fills its third of the cell (so a hint's role tint does); a centered one hugs the digit.
            .frame(width: noteStyle == .grid ? size / 3 : nil, height: noteStyle == .grid ? size / 3 : nil)
            .padding(.horizontal, noteStyle == .center ? size * 0.015 : 0)
            .background(noteBackground(d, roles, cand), in: RoundedRectangle(cornerRadius: size * 0.06))
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
