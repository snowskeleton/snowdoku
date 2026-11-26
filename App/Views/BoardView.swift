import SwiftUI
import SudokuCore

/// Everything a cell needs to draw itself, computed once per board render.
struct BoardContext {
    var selected: Int?
    /// Digit to emphasize: the armed digit, else the selected cell's value.
    var highlightDigit: Int
    var peers: CellSet
    var conflicts: Set<Int>
    var mistakeMode: MistakeMode
    var highlightSame: Bool
    var highlightPeers: Bool
    // Hint overlay
    var hintHouses: CellSet = CellSet()
    var hintRoles: [Int: [Int: Highlight.Role]] = [:]   // cell -> digit (0 = cell) -> role
    var hintElims: Set<Candidate> = []
    var hintPlacements: Set<Candidate> = []
    var hintWrong: Set<Int> = []
    var hintMissing: Set<Candidate> = []

    @MainActor
    init(game: Game, mistakeMode: MistakeMode, highlightSame: Bool, highlightPeers: Bool) {
        selected = game.selected
        highlightDigit = game.armed?.digit ?? game.selected.map { game.value($0) } ?? 0
        peers = game.selected.map { Geometry.peerSets[$0] } ?? CellSet()
        conflicts = mistakeMode == .off ? [] : game.conflicts
        self.mistakeMode = mistakeMode
        self.highlightSame = highlightSame
        self.highlightPeers = highlightPeers

        guard let h = game.hint else { return }
        switch h.hint {
        case .solved: break
        case .wrongValues(let cells):
            hintWrong = Set(cells)
        case .missingCandidates(let cs):
            hintMissing = Set(cs)
        case .step(let s):
            if h.level >= .region {
                let hs = s.houses.isEmpty ? Geometry.sharedHouses(s.patternCells.array) : s.houses
                for house in hs { hintHouses |= Geometry.houseSets[house] }
                if hs.isEmpty { hintHouses = s.patternCells }
            }
            if h.level >= .pattern {
                for hl in s.highlights { hintRoles[hl.cell, default: [:]][hl.digit] = hl.role }
            }
            if h.level >= .answer {
                hintElims = Set(s.eliminations)
                hintPlacements = Set(s.placements)
            }
        }
    }
}

struct BoardView: View {
    let game: Game
    @AppStorage("mistakeMode") private var mistakeMode: MistakeMode = .conflicts
    @AppStorage("highlightSame") private var highlightSame = true
    @AppStorage("highlightPeers") private var highlightPeers = true

    var body: some View {
        let ctx = BoardContext(game: game, mistakeMode: mistakeMode, highlightSame: highlightSame, highlightPeers: highlightPeers)
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = side / 9
            ZStack(alignment: .topLeading) {
                ForEach(0..<81, id: \.self) { c in
                    CellView(game: game, cell: c, ctx: ctx, size: cell)
                        .frame(width: cell, height: cell)
                        .offset(x: CGFloat(c % 9) * cell, y: CGFloat(c / 9) * cell)
                        .contentShape(Rectangle())
                        .onTapGesture { game.tapCell(c) }
                }
                GridLines()
                    .stroke(Color.primary.opacity(0.25), lineWidth: 0.5)
                GridLines(boxesOnly: true)
                    .stroke(Color.primary.opacity(0.85), lineWidth: 2)
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sudoku board")
    }
}

struct GridLines: Shape {
    var boxesOnly = false
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let step = rect.width / 9
        for i in 0...9 where !boxesOnly || i % 3 == 0 {
            if boxesOnly == false && i % 3 == 0 { continue }
            let x = CGFloat(i) * step
            p.move(to: CGPoint(x: x, y: 0)); p.addLine(to: CGPoint(x: x, y: rect.height))
            p.move(to: CGPoint(x: 0, y: x)); p.addLine(to: CGPoint(x: rect.width, y: x))
        }
        return p
    }
}

struct CellView: View {
    let game: Game
    let cell: Int
    let ctx: BoardContext
    let size: CGFloat

    var body: some View {
        let v = game.value(cell)
        ZStack {
            Rectangle().fill(background(v))
            if v != 0 {
                Text("\(v)")
                    .font(.system(size: size * 0.62, weight: game.isGiven(cell) ? .semibold : .regular, design: .rounded))
                    .foregroundStyle(valueColor(v))
            } else {
                NotesView(game: game, cell: cell, ctx: ctx, size: size)
            }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityText(v))
        .accessibilityAddTraits(ctx.selected == cell ? .isSelected : [])
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

    func valueColor(_ v: Int) -> Color {
        if game.isGiven(cell) { return .primary }
        if ctx.mistakeMode == .solution && game.isWrong(cell) { return .red }
        if ctx.mistakeMode == .conflicts && ctx.conflicts.contains(cell) { return .red }
        return .accentColor
    }

    func accessibilityText(_ v: Int) -> String {
        let pos = "Row \(cell / 9 + 1), column \(cell % 9 + 1)"
        if v != 0 { return "\(pos), \(v)\(game.isGiven(cell) ? ", given" : "")" }
        let n = Mask.digits(game.notes[cell])
        return n.isEmpty ? "\(pos), empty" : "\(pos), notes \(n.map(String.init).joined(separator: " "))"
    }
}

struct NotesView: View {
    let game: Game
    let cell: Int
    let ctx: BoardContext
    let size: CGFloat

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

extension Highlight.Role {
    var color: Color {
        switch self {
        case .pattern: .yellow
        case .secondary: .orange
        case .fin: .purple
        case .colorA: .blue
        case .colorB: .green
        case .colorC: .pink
        case .colorD: .teal
        case .chainOn: .green
        case .chainOff: .blue
        }
    }
}
