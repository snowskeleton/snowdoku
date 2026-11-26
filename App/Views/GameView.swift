import SwiftUI
import SudokuCore

struct GameView: View {
    @Bindable var game: Game
    @Environment(GameStore.self) private var store
    @AppStorage("showTimer") private var showTimer = true
    @AppStorage("mistakeMode") private var mistakeMode: MistakeMode = .conflicts
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
                            hintArea
                            Spacer(minLength: 0)
                            ControlsView(game: game)
                            NumberPad(game: game, columns: 3)
                        }
                        .frame(maxWidth: 360)
                    }
                } else {
                    VStack(spacing: 12) {
                        header
                        BoardView(game: game)
                        hintArea
                        Spacer(minLength: 0)
                        ControlsView(game: game)
                        NumberPad(game: game, columns: 9)
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

    @ViewBuilder var hintArea: some View {
        if game.hint != nil {
            HintPanel(game: game)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    func handleKey(_ press: KeyPress) -> KeyPress.Result {
        if let ch = press.characters.first, let d = ch.wholeNumberValue, (1...9).contains(d) {
            game.input(d); return .handled
        }
        switch press.key {
        case .upArrow: game.moveSelection(dr: -1, dc: 0)
        case .downArrow: game.moveSelection(dr: 1, dc: 0)
        case .leftArrow: game.moveSelection(dr: 0, dc: -1)
        case .rightArrow: game.moveSelection(dr: 0, dc: 1)
        case .delete, .deleteForward: game.erase()
        default:
            switch press.characters.lowercased() {
            case "n", "p": game.pencil.toggle()
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
            control("Notes", game.pencil ? "pencil.circle.fill" : "pencil.circle", active: game.pencil) { game.pencil.toggle() }
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

struct NumberPad: View {
    @Bindable var game: Game
    let columns: Int

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: columns), spacing: 6) {
            ForEach(1...9, id: \.self) { d in
                let left = game.remaining(d)
                Button { game.input(d) } label: {
                    VStack(spacing: 0) {
                        Text("\(d)")
                            .font(.system(size: game.pencil ? 22 : 30, weight: .medium, design: .rounded))
                            .foregroundStyle(game.pencil ? .secondary : .primary)
                        Text(left > 0 ? "\(left)" : " ")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: columns == 9 ? 58 : 64)
                    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .opacity(left == 0 ? 0.3 : 1)
                .accessibilityLabel(game.pencil ? "Note \(d)" : "\(d), \(left) remaining")
            }
        }
        .disabled(game.isComplete)
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
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
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
