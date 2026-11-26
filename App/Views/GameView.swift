import SwiftUI
import SudokuCore

struct GameView: View {
    @Bindable var game: Game
    @Environment(GameStore.self) private var store
    @AppStorage("autoComplete") private var autoCompletePref = true
    @AppStorage("autoCompleteThreshold") private var autoCompleteThreshold = 15
    @FocusState private var focused: Bool
    /// Landscape-ish space: board on the left, pads on the right, actions in the toolbar.
    @State private var isWide = false

    var body: some View {
        Group {
            if isWide {
                HStack(spacing: 24) {
                    BoardView(game: game)
                    VStack(spacing: 16) {
                        GameHeader(game: game)
                        Spacer(minLength: 0)
                        GameInputArea(game: game, showsControls: false)
                    }
                    .frame(maxWidth: 360)
                }
                .padding()
            } else {
                VStack(spacing: 12) {
                    GameHeader(game: game)
                    BoardView(game: game)
                }
                .padding(.horizontal)
                .frame(maxHeight: .infinity)
                // Controls and pads are pinned to the bottom; the board takes the rest.
                .safeAreaInset(edge: .bottom) {
                    GameInputArea(game: game, showsControls: true)
                        .padding([.horizontal, .bottom])
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: Bool.self) { $0.size.width > $0.size.height * 1.15 } action: { isWide = $0 }
        .toolbar {
            if isWide {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button("Undo", systemImage: "arrow.uturn.backward", action: game.undo)
                        .disabled(!game.canUndo)
                    Button("Erase", systemImage: "eraser", action: game.erase)
                    Button("Fill notes", systemImage: "square.grid.3x3.middle.filled", action: game.fillNotes)
                    Button("Hint", systemImage: "lightbulb", action: showHint)
                }
            }
        }
        .navigationTitle(game.practice.map { "Practice: \($0.name)" } ?? (game.dailyKey != nil ? "Daily" : game.difficulty.name))
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onAppear { focused = true }
        .onKeyPress(phases: .down, action: handleKey)
        .onChange(of: game.isComplete) { _, done in if done { store.recordCompletion(game) } }
        .onChange(of: game.values) { store.save() }
        .onChange(of: autoCompletePref) { game.refreshAutoComplete() }
        .onChange(of: autoCompleteThreshold) { game.refreshAutoComplete() }
        .sensoryFeedback(.success, trigger: game.isComplete)
        .sensoryFeedback(.error, trigger: game.mistakes)
        .overlay {
            if game.isComplete { CompletionView(game: game) }
        }
    }

    func showHint() {
        withAnimation { game.requestHint() }
    }

    /// Arrow = one cell, Option+arrow = same spot in the next box, Command+arrow = board edge.
    func moveKind(_ press: KeyPress) -> Game.MoveKind {
        if press.modifiers.contains(.command) { return .edge }
        if press.modifiers.contains(.option) { return .box }
        return .cell
    }

    /// Shifted number-row symbols (US layout) map to small digits.
    static let shiftedDigits: [Character: Int] = ["!": 1, "@": 2, "#": 3, "$": 4, "%": 5, "^": 6, "&": 7, "*": 8, "(": 9]

    /// Number = big digit, Shift+number = small (note) digit.
    func handleKey(_ press: KeyPress) -> KeyPress.Result {
        if let ch = press.characters.first {
            if let d = ch.wholeNumberValue, (1...9).contains(d) {
                game.tapDigit(d, small: press.modifiers.contains(.shift)); return .handled
            }
            if let d = Self.shiftedDigits[ch] {
                game.tapDigit(d, small: true); return .handled
            }
        }
        switch press.key {
        case .upArrow: game.moveSelection(dr: -1, dc: 0, kind: moveKind(press))
        case .downArrow: game.moveSelection(dr: 1, dc: 0, kind: moveKind(press))
        case .leftArrow: game.moveSelection(dr: 0, dc: -1, kind: moveKind(press))
        case .rightArrow: game.moveSelection(dr: 0, dc: 1, kind: moveKind(press))
        case .delete, .deleteForward: game.erase()
        case .escape: game.clearSelection()
        default:
            switch press.characters.lowercased() {
            case "h": showHint()
            case "z" where press.modifiers.contains(.command): press.modifiers.contains(.shift) ? game.redo() : game.undo()
            case "u": game.undo()
            default: return .ignored
            }
        }
        return .handled
    }
}

func formatTime(_ t: Double) -> String {
    let s = Int(t)
    return s >= 3600 ? String(format: "%d:%02d:%02d", s / 3600, (s / 60) % 60, s % 60) : String(format: "%d:%02d", s / 60, s % 60)
}

struct ControlsView: View {
    @Bindable var game: Game

    var body: some View {
        HStack {
            Button("Undo", systemImage: "arrow.uturn.backward", action: game.undo)
                .disabled(!game.canUndo)
            Button("Erase", systemImage: "eraser", action: game.erase)
            Button("Fill", systemImage: "square.grid.3x3.middle.filled", action: game.fillNotes)
            Button("Hint", systemImage: "lightbulb", action: showHint)
        }
        .labelStyle(VerticalLabelStyle())
        .buttonStyle(ControlButtonStyle())
        .disabled(game.isComplete)
    }

    func showHint() {
        withAnimation { game.requestHint() }
    }
}

/// Two digit pads: big digits (values) and small digits (notes). With a cell selected they enter
/// into it; with none selected, tapping arms a digit to apply to many cells.
/// Wide spaces get two single rows; narrower ones get two 3x3 grids side by side.
struct DigitPads: View {
    @Bindable var game: Game
    @ScaledMetric private var rowKeyHeight = 56.0
    @ScaledMetric private var noteRowKeyHeight = 44.0
    @ScaledMetric private var gridKeyHeight = 48.0

    var body: some View {
        ViewThatFits(in: .horizontal) {
            VStack(spacing: 8) {
                row(small: false)
                row(small: true)
            }
            .frame(minWidth: 600)
            HStack(spacing: 14) {
                grid(small: false)
                grid(small: true)
            }
        }
        .disabled(game.isComplete)
        // Past this size the pads would squeeze the board too much.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    func row(small: Bool) -> some View {
        HStack(spacing: 6) {
            ForEach(1...9, id: \.self) { d in DigitKey(game: game, digit: d, small: small, height: small ? noteRowKeyHeight : rowKeyHeight) }
        }
    }

    func grid(small: Bool) -> some View {
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(0..<3, id: \.self) { r in
                GridRow {
                    ForEach(1...3, id: \.self) { k in DigitKey(game: game, digit: r * 3 + k, small: small, height: gridKeyHeight) }
                }
            }
        }
    }
}

struct DigitKey: View {
    @Bindable var game: Game
    let digit: Int
    let small: Bool
    let height: Double
    @ScaledMetric(relativeTo: .title) private var digitSize = 28.0
    @ScaledMetric(relativeTo: .body) private var noteSize = 15.0

    var body: some View {
        let left = game.remaining(digit)
        let armed = game.armed == ArmedDigit(digit: digit, small: small)
        Button { game.tapDigit(digit, small: small) } label: {
            ZStack(alignment: small ? notePosition : .center) {
                Color.clear
                if small {
                    Text("\(digit)")
                        .font(.system(size: noteSize, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 8).padding(.vertical, 5)
                } else {
                    VStack(spacing: 0) {
                        Text("\(digit)").font(.system(size: digitSize, weight: .medium, design: .rounded))
                        if left > 0 { Text("\(left)").font(.caption2).foregroundStyle(.secondary) }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
        }
        .buttonStyle(PadKeyStyle(armed: armed, small: small, finished: !small && left == 0))
        .accessibilityLabel(small ? "Note \(digit)" : "\(digit), \(left) remaining")
        .accessibilityAddTraits(armed ? .isSelected : [])
    }

    /// Small digits sit where they'd appear in a cell's notes.
    var notePosition: Alignment {
        let i = digit - 1
        let h: [HorizontalAlignment] = [.leading, .center, .trailing]
        let v: [VerticalAlignment] = [.top, .center, .bottom]
        return Alignment(horizontal: h[i % 3], vertical: v[i / 3])
    }
}

struct HintPanel: View {
    @Bindable var game: Game

    var body: some View {
        if let h = game.hint {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
                    Text(text(h)).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button { withAnimation { game.hint = nil } } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("Close hint")
                }
                HStack {
                    if case .step = h.hint, h.level < .answer {
                        Button("Show more") { withAnimation { game.requestHint() } }
                            .buttonStyle(.bordered)
                    }
                    Spacer()
                    if applicable(h) {
                        Button(applyLabel(h)) { withAnimation { game.applyHint() } }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Color.primary.opacity(0.08)))
            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        }
    }

    func text(_ h: HintSession) -> String {
        switch h.hint {
        case .solved: return "The puzzle is solved!"
        case .wrongValues(let cells):
            return cells.count == 1 ? "\(Geometry.cellName(cells[0])) has the wrong value." : "\(cells.count) cells have wrong values."
        case .missingCandidates(let cs):
            return "Some of your notes removed the real answer: \(cs.prefix(4).map(\.description).joined(separator: ", "))\(cs.count > 4 ? "…" : "")."
        case .step(let s):
            return s.hintText(h.level)
        }
    }

    func applicable(_ h: HintSession) -> Bool {
        switch h.hint {
        case .solved: false
        case .step: h.level == .answer
        default: true
        }
    }

    func applyLabel(_ h: HintSession) -> String {
        switch h.hint {
        case .wrongValues: "Clear them"
        case .missingCandidates: "Restore notes"
        default: "Apply"
        }
    }
}

struct CompletionView: View {
    let game: Game
    @Environment(GameStore.self) private var store

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 48)).foregroundStyle(.green)
            Text("Solved!").font(.largeTitle.bold())
            Text("\(game.difficulty.name) · \(formatTime(game.elapsed()))")
                .foregroundStyle(.secondary)
            if game.hintsUsed > 0 || game.mistakes > 0 {
                Text("\(game.hintsUsed) hint\(game.hintsUsed == 1 ? "" : "s") · \(game.mistakes) mistake\(game.mistakes == 1 ? "" : "s")")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if !game.techniques.filter({ $0.difficulty > .beginner }).isEmpty {
                Text("Techniques: " + game.techniques.filter { $0.difficulty > .beginner }.map(\.name).joined(separator: ", "))
                    .font(.footnote).multilineTextAlignment(.center).foregroundStyle(.secondary)
            }
            HStack {
                Button("Home") { store.leaveGame() }.buttonStyle(.bordered)
                Button("Next puzzle") {
                    let d = game.difficulty
                    Task { await store.newGame(GameStore.playable.contains(d) ? d : .master) }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding()
    }
}
