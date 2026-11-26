import Foundation
import Observation
import SudokuCore

@Observable @MainActor
final class Game {
    let id: UUID
    let puzzle: Grid
    let solution: Grid
    let givens: CellSet
    let difficulty: Difficulty
    let hardest: Technique
    let techniques: [Technique]
    let dailyKey: String?
    let practice: Technique?

    private(set) var values: [UInt8]
    private(set) var notes: [DigitMask]
    var selected: Int?
    var armed: ArmedDigit?
    /// Digit just entered via a selected cell; keeps matching digits highlighted after the selection clears.
    var lastDigit: Int?
    /// Last selected cell, so arrow keys continue from it after the selection clears.
    private var lastCell: Int?
    private(set) var mistakes: Int
    private(set) var hintsUsed: Int
    private(set) var isComplete: Bool
    var hint: HintSession?
    /// True when the rest of the puzzle is obvious and the player may finish it with one tap.
    private(set) var canAutoComplete = false
    private(set) var autoCompleting = false

    private var accumulated: Double
    private var resumedAt: Date?

    private struct Snapshot { var values: [UInt8]; var notes: [DigitMask] }
    private var undoStack: [Snapshot] = []
    private var redoStack: [Snapshot] = []

    init(_ p: GeneratedPuzzle, dailyKey: String? = nil, practice: Technique? = nil) {
        id = UUID()
        puzzle = p.puzzle
        solution = p.solution
        givens = CellSet((0..<81).filter { p.puzzle[$0] != 0 })
        difficulty = p.rating.difficulty
        hardest = p.rating.hardest
        techniques = p.rating.techniques
        self.dailyKey = dailyKey
        self.practice = practice
        values = p.puzzle.cells
        notes = Array(repeating: 0, count: 81)
        mistakes = 0
        hintsUsed = 0
        isComplete = false
        accumulated = 0
        resumedAt = Date.now
        refreshAutoComplete()
    }

    init(record r: GameRecord) {
        id = r.id
        puzzle = r.puzzle
        solution = r.solution
        givens = CellSet((0..<81).filter { r.puzzle[$0] != 0 })
        difficulty = r.difficulty
        hardest = r.hardest
        techniques = r.techniques
        dailyKey = r.dailyKey
        practice = r.practice
        values = r.values
        notes = r.notes
        mistakes = r.mistakes
        hintsUsed = r.hintsUsed
        isComplete = r.completed
        accumulated = r.elapsed
        resumedAt = r.completed ? nil : Date.now
        refreshAutoComplete()
    }

    var record: GameRecord {
        GameRecord(id: id, puzzle: puzzle, solution: solution, values: values, notes: notes, elapsed: elapsed(),
                   mistakes: mistakes, hintsUsed: hintsUsed, difficulty: difficulty, hardest: hardest,
                   techniques: techniques, dailyKey: dailyKey, practice: practice, completed: isComplete)
    }

    // MARK: Clock

    func elapsed(at date: Date = Date.now) -> Double {
        accumulated + (resumedAt.map { date.timeIntervalSince($0) } ?? 0)
    }
    func pauseClock() {
        accumulated = elapsed()
        resumedAt = nil
    }
    func resumeClock() {
        if resumedAt == nil && !isComplete { resumedAt = Date.now }
    }
    var isPaused: Bool { resumedAt == nil }

    // MARK: Queries

    func isGiven(_ c: Int) -> Bool { givens.contains(c) }
    func value(_ c: Int) -> Int { Int(values[c]) }
    func isWrong(_ c: Int) -> Bool { values[c] != 0 && Int(values[c]) != solution[c] }

    /// Cells whose value repeats in one of their houses.
    var conflicts: Set<Int> {
        var out = Set<Int>()
        for h in Geometry.houses {
            var seen: [Int: Int] = [:]
            for c in h where values[c] != 0 {
                if let other = seen[Int(values[c])] { out.insert(c); out.insert(other) } else { seen[Int(values[c])] = c }
            }
        }
        return out
    }

    func remaining(_ d: Int) -> Int { 9 - values.reduce(0) { $0 + ($1 == UInt8(d) ? 1 : 0) } }

    var canUndo: Bool { !undoStack.isEmpty }
    var canRedo: Bool { !redoStack.isEmpty }

    // MARK: Editing

    private func pushUndo() {
        undoStack.append(Snapshot(values: values, notes: notes))
        if undoStack.count > 500 { undoStack.removeFirst() }
        redoStack.removeAll()
        hint = nil
    }

    func undo() {
        guard !autoCompleting, let s = undoStack.popLast() else { return }
        redoStack.append(Snapshot(values: values, notes: notes))
        values = s.values; notes = s.notes
        hint = nil
        refreshAutoComplete()
    }

    func redo() {
        guard !autoCompleting, let s = redoStack.popLast() else { return }
        undoStack.append(Snapshot(values: values, notes: notes))
        values = s.values; notes = s.notes
        hint = nil
        refreshAutoComplete()
    }

    // MARK: Input

    /// Tapping a cell applies the armed digit, or toggles selection.
    func tapCell(_ c: Int) {
        guard !autoCompleting else { return }
        if let a = armed {
            if a.small { toggleNote(a.digit, at: c) } else { place(a.digit, at: c) }
            return
        }
        selected = selected == c ? nil : c
        lastCell = c
        lastDigit = nil
    }

    /// Tapping a pad digit (or typing it): with a selected cell, enter it there;
    /// otherwise arm the digit so it can be applied to many cells. Tapping the armed digit disarms it.
    func tapDigit(_ d: Int, small: Bool) {
        guard !autoCompleting else { return }
        if let c = selected {
            if small {
                toggleNote(d, at: c)
            } else {
                // A value finishes with that cell: clear the selection so the next digit tap arms a digit.
                place(d, at: c)
                selected = nil
                lastDigit = values[c] != 0 ? d : nil
            }
            return
        }
        lastDigit = nil
        let a = ArmedDigit(digit: d, small: small)
        armed = armed == a ? nil : a
    }

    func clearSelection() {
        selected = nil
        armed = nil
        lastDigit = nil
    }

    func place(_ d: Int, at c: Int) {
        guard !isComplete, !isGiven(c) else { return }
        pushUndo()
        if values[c] == UInt8(d) {
            values[c] = 0
            return
        }
        values[c] = UInt8(d)
        notes[c] = 0
        if Prefs.autoRemoveNotes {
            let bit = ~Mask.bit(d)
            for p in Geometry.peers[c] { notes[p] &= bit }
        }
        if d != solution[c] { mistakes += 1 }
        checkComplete()
    }

    func toggleNote(_ d: Int, at c: Int) {
        guard !isComplete, values[c] == 0 else { return }
        pushUndo()
        notes[c] ^= Mask.bit(d)
    }

    func erase() {
        guard !isComplete, !autoCompleting, let c = selected, !isGiven(c), values[c] != 0 || notes[c] != 0 else { return }
        pushUndo()
        if values[c] != 0 { values[c] = 0 } else { notes[c] = 0 }
        refreshAutoComplete()
    }

    /// Fills every empty cell with all candidates that don't conflict with placed values.
    func fillNotes() {
        guard !isComplete else { return }
        pushUndo()
        for c in 0..<81 where values[c] == 0 {
            var m = Mask.all
            for p in Geometry.peers[c] where values[p] != 0 { m &= ~Mask.bit(Int(values[p])) }
            notes[c] = m
        }
    }

    enum MoveKind { case cell, box, edge }

    /// Moves the selection one cell, one box (same position in the neighboring box), or to the edge.
    /// Cell and box moves wrap around the board.
    func moveSelection(dr: Int, dc: Int, kind: MoveKind = .cell) {
        let c = selected ?? lastCell ?? 40
        var r = c / 9, col = c % 9
        switch kind {
        case .cell:
            r = (r + dr + 9) % 9; col = (col + dc + 9) % 9
        case .box:
            r = (r + 3 * dr + 9) % 9; col = (col + 3 * dc + 9) % 9
        case .edge:
            if dr != 0 { r = dr < 0 ? 0 : 8 }
            if dc != 0 { col = dc < 0 ? 0 : 8 }
        }
        selected = r * 9 + col
        lastCell = selected
        lastDigit = nil
    }

    private func checkComplete() {
        refreshAutoComplete()
        if values == solution.cells {
            isComplete = true
            pauseClock()
            selected = nil
            armed = nil
            hint = nil
        }
    }

    // MARK: Auto-complete

    static let singlesSolver = HumanSolver(allowing: [.fullHouse, .hiddenSingleBox, .hiddenSingleLine, .nakedSingle])

    /// Offered above Beginner when there are no wrong entries, few cells remain, and
    /// singles alone finish the puzzle from here.
    func refreshAutoComplete() {
        canAutoComplete = remainingPlacements() != nil
    }

    /// The remaining placements in the order a singles-only solve finds them, or nil if not eligible.
    private func remainingPlacements() -> [Candidate]? {
        guard difficulty > .beginner, Prefs.autoComplete, !isComplete, !autoCompleting else { return nil }
        let empty = values.reduce(0) { $0 + ($1 == 0 ? 1 : 0) }
        guard empty > 0, empty <= Prefs.autoCompleteThreshold else { return nil }
        guard !(0..<81).contains(where: { isWrong($0) }) else { return nil }
        let log = Self.singlesSolver.solve(Board(Grid(cells: values)))
        guard log.solved, log.final.values == solution.cells else { return nil }
        return log.steps.flatMap(\.placements)
    }

    /// Fills the rest of the board, one cell at a time unless `animated` is false.
    func autoComplete(animated: Bool) async {
        guard let placements = remainingPlacements() else { return }
        pushUndo()
        pauseClock()
        autoCompleting = true
        canAutoComplete = false
        selected = nil
        armed = nil
        for p in placements {
            values[p.cell] = UInt8(p.digit)
            notes[p.cell] = 0
            lastDigit = p.digit
            // Slow enough to watch each cell fill in.
            if animated { try? await Task.sleep(for: .milliseconds(500)) }
        }
        autoCompleting = false
        checkComplete()
    }

    #if DEBUG
    /// Test hook: fill every empty cell from the solution except the last `leaving` ones.
    func debugPrefill(leaving: Int, wrong: Bool) {
        let empties = (0..<81).filter { values[$0] == 0 }
        for c in empties.dropLast(leaving) { values[c] = UInt8(solution[c]) }
        if wrong, let c = empties.first { values[c] = UInt8(solution[c] % 9 + 1) }
        refreshAutoComplete()
    }
    #endif

    // MARK: Hints

    /// First press computes a hint at the nudge level; later presses reveal more.
    func requestHint() {
        guard !isComplete else { return }
        if var h = hint {
            if let next = HintLevel(rawValue: h.level.rawValue + 1) { h.level = next; hint = h }
            return
        }
        let result = HintEngine.hint(values: values, notes: notes, givens: givens, solution: solution)
        hintsUsed += 1
        let start: HintLevel
        switch result {
        case .step: start = .nudge
        default: start = .answer
        }
        hint = HintSession(hint: result, level: start)
    }

    /// Applies what the current hint shows (fixes mistakes, restores notes or performs the step).
    func applyHint() {
        guard let h = hint else { return }
        pushUndo()
        switch h.hint {
        case .solved: break
        case .wrongValues(let cells):
            for c in cells { values[c] = 0 }
        case .missingCandidates(let cs):
            for c in cs { notes[c.cell] |= Mask.bit(c.digit) }
        case .step(let s):
            for e in s.eliminations { notes[e.cell] &= ~Mask.bit(e.digit) }
            for p in s.placements {
                values[p.cell] = UInt8(p.digit)
                notes[p.cell] = 0
                if Prefs.autoRemoveNotes {
                    for q in Geometry.peers[p.cell] { notes[q] &= ~Mask.bit(p.digit) }
                }
                selected = p.cell
            }
            checkComplete()
        }
        hint = nil
    }
}
