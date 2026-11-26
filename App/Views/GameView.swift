import SwiftUI
import SudokuCore

struct GameView: View {
    @Bindable var game: Game
    @Environment(GameStore.self) private var store
    @AppStorage("showTimer") private var showTimer = true
    @AppStorage("mistakeMode") private var mistakeMode: MistakeMode = .conflicts
    @AppStorage("autoComplete") private var autoCompletePref = true
    @AppStorage("autoCompleteThreshold") private var autoCompleteThreshold = 15
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: Bool

    var body: some View {
        GeometryReader { geo in
            let wide = geo.size.width > geo.size.height * 1.15
            Group {
                if wide {
                    HStack(alignment: .center, spacing: 24) {
                        BoardView(game: game)
                        VStack(spacing: 16) {
                            header
                            Spacer(minLength: 0)
                            inputArea
                        }
                        .frame(maxWidth: 360)
                    }
                } else {
                    VStack(spacing: 12) {
                        header
                        BoardView(game: game)
                        Spacer(minLength: 0)
                        inputArea
                    }
                }
            }
            .padding()
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

    var header: some View {
        HStack {
            Label(game.difficulty.name, systemImage: "chart.bar.fill")
                .foregroundStyle(.secondary)
            Spacer()
            if mistakeMode == .solution {
                Label("\(game.mistakes)", systemImage: "xmark.circle")
                    .foregroundStyle(game.mistakes > 0 ? .red : .secondary)
            }
            if showTimer {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text(formatTime(game.elapsed(at: ctx.date)))
                        .monospacedDigit()
                }
                .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
    }

    /// Controls and pads. The hint panel floats over them (never over the board, whose
    /// highlights it refers to) so nothing moves when it appears.
    var inputArea: some View {
        VStack(spacing: 12) {
            ControlsView(game: game)
            DigitPads(game: game)
        }
        .overlay(alignment: .bottom) {
            if game.hint != nil {
                HintPanel(game: game)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) {
            if game.canAutoComplete && game.hint == nil {
                Button {
                    Task { await game.autoComplete(animated: !reduceMotion) }
                } label: {
                    Label("Finish puzzle", systemImage: "wand.and.stars")
                        .font(.headline)
                        .padding(.horizontal, 18).padding(.vertical, 10)
                        .background(Color.accentColor, in: Capsule())
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.2), radius: 8, y: 3)
                }
                .buttonStyle(.plain)
                // Float just above the controls row, never over the buttons.
                .offset(y: -54)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: game.canAutoComplete)
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
            case "h": withAnimation { game.requestHint() }
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
            control("Undo", "arrow.uturn.backward", disabled: !game.canUndo) { game.undo() }
            control("Erase", "eraser") { game.erase() }
            control("Fill", "square.grid.3x3.middle.filled") { game.fillNotes() }
            control("Hint", "lightbulb") { withAnimation { game.requestHint() } }
        }
        .disabled(game.isComplete)
    }

    func control(_ title: String, _ icon: String, active: Bool = false, disabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.title2)
                Text(title).font(.caption)
            }
            .frame(maxWidth: .infinity, minHeight: 50)
            .foregroundStyle(active ? Color.accentColor : .primary)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1)
    }
}

/// Two digit pads: big digits (values) and small digits (notes). With a cell selected they enter
/// into it; with none selected, tapping arms a digit to apply to many cells.
/// Wide spaces get two single rows; narrower ones get two 3x3 grids side by side.
struct DigitPads: View {
    @Bindable var game: Game

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
    }

    func row(small: Bool) -> some View {
        HStack(spacing: 6) {
            ForEach(1...9, id: \.self) { d in DigitKey(game: game, digit: d, small: small, height: small ? 44 : 56) }
        }
    }

    func grid(small: Bool) -> some View {
        Grid(horizontalSpacing: 6, verticalSpacing: 6) {
            ForEach(0..<3, id: \.self) { r in
                GridRow {
                    ForEach(1...3, id: \.self) { k in DigitKey(game: game, digit: r * 3 + k, small: small, height: 48) }
                }
            }
        }
    }
}

struct DigitKey: View {
    @Bindable var game: Game
    let digit: Int
    let small: Bool
    let height: CGFloat

    var body: some View {
        let left = game.remaining(digit)
        let armed = game.armed == ArmedDigit(digit: digit, small: small)
        Button { game.tapDigit(digit, small: small) } label: {
            ZStack(alignment: small ? notePosition : .center) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(armed ? Color.accentColor : Color.primary.opacity(0.06))
                if small {
                    Text("\(digit)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 8).padding(.vertical, 5)
                } else {
                    VStack(spacing: 0) {
                        Text("\(digit)").font(.system(size: 28, weight: .medium, design: .rounded))
                        if left > 0 { Text("\(left)").font(.caption2).opacity(0.6) }
                    }
                }
            }
            .foregroundStyle(armed ? Color.white : (small ? Color.secondary : Color.primary))
            .frame(maxWidth: .infinity, minHeight: height, maxHeight: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(!small && left == 0 ? 0.3 : 1)
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
