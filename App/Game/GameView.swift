import SwiftUI
import SudokuCore

struct GameView: View {
    @Bindable var game: Game
    @Environment(GameStore.self) private var store
    @Environment(StatsStore.self) private var stats
    @AppStorage("autoComplete") private var autoCompletePref = true
    @AppStorage("autoCompleteThreshold") private var autoCompleteThreshold = 15
    @AppStorage("padLayout") private var padLayout: PadLayout = .twoPads
    @AppStorage("noteNotation") private var notation: NoteNotation = .manual
    @FocusState private var focused: Bool
    /// Landscape-ish space: board on the left, controls and pads on the right.
    @State private var isWide = false

    var body: some View {
        Group {
            if isWide {
                HStack(spacing: 24) {
                    BoardView(game: game)
                    VStack(spacing: 16) {
                        GameHeader(game: game)
                        Spacer(minLength: 0)
                        GameInputArea(game: game)
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
                    GameInputArea(game: game)
                        .padding([.horizontal, .bottom])
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onGeometryChange(for: Bool.self) { $0.size.width > $0.size.height * 1.15 } action: { isWide = $0 }
        .navigationTitle(game.title)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .focusable()
        .focused($focused)
        .focusEffectDisabled()
        .onAppear { focused = true }
        .onKeyPress(phases: .down, action: handleKey)
        .onChange(of: game.isComplete) { _, done in
            if done { store.recordCompletion(game) }
            if done && game.drill == nil { Task { await stats.recordMoves(game) } }
        }
        // A drill's move is the drill; whatever the player solves after it isn't tracked.
        .onChange(of: game.drillState) { _, s in
            if s == .found {
                store.recordCampaignDrill(game)
                // Lesson questions point at the answer's area, so their times say little about skill.
                if !game.isLesson {
                    if let t = game.drill?.technique { stats.recordDrill(t) }
                    Task { await stats.recordMoves(game) }
                }
            }
        }
        .onChange(of: game.digitFirst) { _, d in
            if let d, game.drill == nil, game.campaign == nil { stats.recordDigitFirst(d) }
        }
        .onChange(of: game.values) { store.save() }
        .onChange(of: autoCompletePref) { game.refreshAutoComplete() }
        .onChange(of: autoCompleteThreshold) { game.refreshAutoComplete() }
        .sensoryFeedback(.success, trigger: game.isComplete)
        .sensoryFeedback(.error, trigger: game.mistakes)
        .sensoryFeedback(.warning, trigger: game.attempts)
        .sensoryFeedback(.impact(weight: .light), trigger: game.digitsCompleted)
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

    /// Number = big digit, Shift+number = small (note) digit. With one pad in Notes or Center mode, a
    /// plain number is that kind of note, and N steps through the modes.
    func handleKey(_ press: KeyPress) -> KeyPress.Result {
        if let ch = press.characters.first {
            if let d = ch.wholeNumberValue, (1...9).contains(d) {
                if press.modifiers.contains(.shift) { game.tapDigit(d, small: true, kind: notation.kind); return .handled }
                let mode = padLayout == .onePad ? game.padMode : .digits
                game.tapDigit(d, small: mode != .digits, kind: padLayout == .onePad ? mode.noteKind : notation.kind); return .handled
            }
            if let d = Self.shiftedDigits[ch] {
                game.tapDigit(d, small: true, kind: notation.kind); return .handled
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
            case "n" where padLayout == .onePad: game.choosePadMode(game.padMode.next)
            case "z" where press.modifiers.contains(.command): press.modifiers.contains(.shift) ? game.redo() : game.undo()
            case "u": game.undo()
            default: return .ignored
            }
        }
        return .handled
    }
}
