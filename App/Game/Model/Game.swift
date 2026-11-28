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
    /// Set for a technique drill: a mid-solve position whose next move is the drill's technique.
    let drill: Drill?
    /// Set for a campaign game (a level, or a drill of a chapter's drill round).
    let campaign: CampaignContext?
    var drillState: DrillState = .searching
    /// In a campaign drill round: whether this drill counted (set once its move is found).
    var campaignDrillClean: Bool?
    /// Every instance of the drill's technique in the starting position, computed in the background.
    private(set) var drillTargets: [Step] = []
    /// In a singles drill or lesson: the part of the board the question is about. Moves outside it
    /// are ignored, and a move inside it that isn't the answer bounces back with `coach` feedback.
    let spotlight: Spotlight?
    /// The coaching card over the controls: a spotlight's intro, or why a move wasn't the answer.
    var coach: Coach?

    private(set) var values: [UInt8] { didSet { checkDrill(); trackProgress() } }
    private(set) var notes: [DigitMask] { didSet { checkDrill() } }
    /// How each cell draws its notes (`NoteKind`), set by the note last added to it: cells in
    /// `centeredNotes` are centered, cells in `autoNotes` go by count, the rest use the grid.
    private(set) var centeredNotes = CellSet()
    private(set) var autoNotes = CellSet()
    /// The selected cell. Setting it (to anything) ends a multi-selection.
    var selected: Int? { didSet { multiSelection = CellSet() } }
    /// Two or more cells selected by dragging with nothing armed (`selected` is the first of them).
    /// Pad digits, Erase and the note-style switch then apply to all of them at once.
    private(set) var multiSelection = CellSet()
    /// Every selected cell: the multi-selection, else the selected cell.
    var selectedCells: [Int] { multiSelection.isEmpty ? (selected.map { [$0] } ?? []) : multiSelection.array }
    var armed: ArmedDigit?
    /// One-pad layout: what the pad enters.
    var padMode = PadMode.digits {
        // An armed digit follows the switch, so it keeps applying what the pad now shows.
        didSet { if let a = armed { armed = ArmedDigit(digit: a.digit, small: padMode != .digits, kind: padMode.noteKind) } }
    }
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
    /// Per-cell flash counters: bumping one makes that cell flash on and fade out. Each cell has its
    /// own so overlapping flashes (auto-complete's quick fills) fade independently.
    private(set) var flashes = Array(repeating: 0, count: 81)
    /// Bumped each time a digit is completed (for the haptic).
    private(set) var digitsCompleted = 0
    /// Bumped each time a spotlight bounces a move (for the haptic and the shake).
    private(set) var attempts = 0

    private var accumulated: Double
    private var resumedAt: Date?

    /// Every move so far and the technique it needed (see `TechniqueMove`).
    private(set) var moves: [TechniqueMove]
    /// The move being worked on: since the last correct digit. Its technique is worked out when
    /// it ends, from the cell the player filled.
    private struct Segment {
        var start: Double
        var mistakes = 0
        var hintLevel: HintLevel?
        /// The correct digits when the move began (wrong ones blanked).
        var values: [UInt8]
        /// In a drill, the drill's technique.
        var drill: Technique?
    }
    private var segment: Segment?
    /// Correct digits on the board, givens included.
    private var progress = 0
    /// Set while undo, redo or auto-complete change the board, which aren't the player's moves.
    private var untracked = false
    /// Set while the hint's Apply button changes the board.
    private var applyingHint = false
    /// Moves whose technique is still being computed.
    private var pendingMoves: [Task<Void, Never>] = []
    /// Set once the moves have gone to the statistics, so they're counted once.
    var movesRecorded = false

    private struct Snapshot { var values: [UInt8]; var notes: [DigitMask]; var centered: CellSet; var auto: CellSet }
    private var snapshot: Snapshot { Snapshot(values: values, notes: notes, centered: centeredNotes, auto: autoNotes) }
    private func restore(_ s: Snapshot) { values = s.values; notes = s.notes; centeredNotes = s.centered; autoNotes = s.auto }
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
        drill = nil
        campaign = nil
        spotlight = nil
        moves = []
        refreshAutoComplete()
        startTracking()
    }

    /// Starts a campaign puzzle (already transformed), mid-solve with notes when it has them.
    init(campaign c: CampaignContext, puzzle p: CampaignPuzzle, solution: Grid) {
        id = UUID()
        puzzle = p.puzzle
        self.solution = solution
        givens = p.givens
        let ch = c.chapterInfo
        difficulty = ch?.lead.difficulty ?? .easy
        hardest = ch?.lead ?? .nakedSingle
        techniques = ch?.family ?? []
        dailyKey = nil
        practice = nil
        drill = nil
        campaign = c
        spotlight = nil
        values = (p.values ?? p.puzzle).cells
        notes = p.candidates ?? Array(repeating: 0, count: 81)
        mistakes = 0
        hintsUsed = 0
        isComplete = false
        accumulated = 0
        resumedAt = Date.now
        moves = []
        refreshAutoComplete()
        startTracking()
    }

    /// Starts a drill. `tracking` is false for the static examples on technique pages.
    init(drill d: Drill, solution: Grid, tracking: Bool = true, campaign c: CampaignContext? = nil, spotlight sp: Spotlight? = nil) {
        id = UUID()
        puzzle = d.puzzle
        self.solution = solution
        givens = d.givens
        difficulty = d.technique.difficulty
        hardest = d.technique
        techniques = [d.technique]
        dailyKey = nil
        practice = d.technique
        drill = d
        campaign = c
        spotlight = sp
        values = d.values.cells
        notes = d.showsNotes ? d.candidates : Array(repeating: 0, count: 81)
        mistakes = 0
        hintsUsed = 0
        isComplete = false
        accumulated = 0
        resumedAt = Date.now
        moves = []
        refreshAutoComplete()
        if sp != nil {
            // Singles are cheap to find, and a spotlight needs its answers before the first tap.
            drillTargets = d.targets()
            prepareSpotlight()
        }
        if tracking { if sp == nil { loadDrillTargets() }; startTracking() }
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
        drill = r.drill
        campaign = r.campaign
        spotlight = r.spotlight
        drillState = r.drillState ?? .searching
        values = r.values
        notes = r.notes
        centeredNotes = r.centeredNotes ?? CellSet()
        autoNotes = r.autoNotes ?? CellSet()
        mistakes = r.mistakes
        hintsUsed = r.hintsUsed
        isComplete = r.completed
        accumulated = r.elapsed
        resumedAt = r.completed ? nil : Date.now
        moves = r.moves ?? []
        refreshAutoComplete()
        if let d = drill, drillState == .searching {
            if spotlight != nil { drillTargets = d.targets(); prepareSpotlight() } else { loadDrillTargets() }
        }
        startTracking()
    }

    var record: GameRecord {
        GameRecord(id: id, puzzle: puzzle, solution: solution, values: values, notes: notes, centeredNotes: centeredNotes, autoNotes: autoNotes, elapsed: elapsed(),
                   mistakes: mistakes, hintsUsed: hintsUsed, difficulty: difficulty, hardest: hardest,
                   techniques: techniques, dailyKey: dailyKey, practice: practice, completed: isComplete,
                   drill: drill, drillState: drill == nil ? nil : drillState, moves: moves, campaign: campaign,
                   spotlight: spotlight)
    }

    var title: String {
        if let ch = campaign?.chapterInfo { return ch.title }
        if let drill { return "Drill: \(drill.technique.name)" }
        if let practice { return "Practice: \(practice.name)" }
        return dailyKey != nil ? "Daily" : difficulty.name
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
        undoStack.append(snapshot)
        if undoStack.count > 500 { undoStack.removeFirst() }
        redoStack.removeAll()
        hint = nil
    }

    func undo() {
        guard !autoCompleting, let s = undoStack.popLast() else { return }
        redoStack.append(snapshot)
        untracked = true
        restore(s)
        untracked = false
        hint = nil
        refreshAutoComplete()
    }

    func redo() {
        guard !autoCompleting, let s = redoStack.popLast() else { return }
        undoStack.append(snapshot)
        untracked = true
        restore(s)
        untracked = false
        hint = nil
        refreshAutoComplete()
    }

    // MARK: Input

    /// Tapping a cell applies the armed digit, or toggles selection.
    /// `asNote`: shift-click, which enters the armed digit as a note whichever pad it was armed from.
    func tapCell(_ c: Int, asNote: Bool = false) {
        guard !autoCompleting, inSpotlight(c) else { return }
        if let a = armed {
            if a.small { toggleNote(a.digit, at: c, kind: a.kind) }
            else if asNote { toggleNote(a.digit, at: c, kind: Prefs.noteNotation.kind) }
            else { place(a.digit, at: c) }
            return
        }
        // Tapping a cell of a multi-selection selects just that cell.
        selected = selected == c && multiSelection.isEmpty ? nil : c
        lastCell = c
        lastDigit = nil
    }

    /// Tapping a pad digit (or typing it): with a selected cell, enter it there;
    /// otherwise arm the digit so it can be applied to many cells. Tapping the armed digit disarms it.
    /// `kind`: how an added note is drawn (the one-pad mode, or the Manual / Auto setting).
    func tapDigit(_ d: Int, small: Bool, kind: NoteKind = .grid) {
        guard !autoCompleting else { return }
        if !multiSelection.isEmpty {
            applyToSelection(d, asNote: small, kind: kind)
            if !small { selected = nil; lastDigit = d }
            return
        }
        if let c = selected {
            if small {
                toggleNote(d, at: c, kind: kind)
            } else {
                // A value finishes with that cell: clear the selection so the next digit tap arms a digit.
                place(d, at: c)
                // A move the spotlight bounced leaves the cell selected for another try.
                if values[c] != 0 || !spotlightActive { selected = nil }
                lastDigit = values[c] != 0 ? d : nil
            }
            return
        }
        lastDigit = nil
        let a = ArmedDigit(digit: d, small: small, kind: small ? kind : .grid)
        armed = armed == a ? nil : a
    }

    func clearSelection() {
        selected = nil
        armed = nil
        lastDigit = nil
    }

    func place(_ d: Int, at c: Int) {
        guard !isComplete, !isGiven(c), inSpotlight(c) else { return }
        if spotlightActive && values[c] != UInt8(d) && !answersSpotlight(d, at: c) { bounce(d, at: c); return }
        pushUndo()
        if values[c] == UInt8(d) {
            values[c] = 0
            return
        }
        writeValue(d, at: c)
    }

    private func writeValue(_ d: Int, at c: Int) {
        values[c] = UInt8(d)
        notes[c] = 0
        if Prefs.autoRemoveNotes {
            let bit = ~Mask.bit(d)
            for p in Geometry.peers[c] { notes[p] &= bit }
        }
        if d != solution[c] { mistakes += 1; segment?.mistakes += 1 }
        flashIfCompleted(d)
        checkComplete()
    }

    /// Right-click: remove the armed digit's note from a cell (never adds one).
    func removeArmedNote(at c: Int) {
        guard !autoCompleting, let a = armed, notes[c] & Mask.bit(a.digit) != 0 else { return }
        toggleNote(a.digit, at: c)
    }

    // MARK: Drags and multi-selection

    /// One digit applied to many cells, by a drag with a digit armed or to a multi-selection. It
    /// either adds or removes everywhere (decided up front), and it is one undo step.
    private struct Edit {
        var digit: Int
        var asNote: Bool
        var kind: NoteKind
        var adding: Bool
        var pushedUndo = false
    }

    /// A drag in progress: applying the armed digit (`edit`), or, with nothing armed, selecting.
    private struct Stroke {
        var edit: Edit?
        var visited = CellSet()
    }
    private var stroke: Stroke?

    /// Starts a drag at cell `c`. With a digit armed, the first cell decides whether the drag adds
    /// or removes, and every cell it crosses gets the same change. With nothing armed it selects
    /// the cells it crosses. `asNote`: Shift held, as for a Shift-click.
    func beginStroke(at c: Int, asNote: Bool = false) {
        guard !autoCompleting, !isComplete else { return }
        guard inSpotlight(c) else { return }
        guard let a = armed else {
            stroke = Stroke()
            selected = c
            lastCell = c
            lastDigit = nil
            extendStroke(to: c)
            return
        }
        let note = a.small || asNote
        let adding = note ? (values[c] != 0 || notes[c] & Mask.bit(a.digit) == 0)
            : values[c] != UInt8(a.digit)
        stroke = Stroke(edit: Edit(digit: a.digit, asNote: note, kind: a.small ? a.kind : Prefs.noteNotation.kind,
                                   adding: adding))
        extendStroke(to: c)
    }

    /// Applies the drag to `c`, once per cell per drag.
    func extendStroke(to c: Int) {
        guard var s = stroke, !isComplete, !s.visited.contains(c) else { return }
        s.visited.insert(c)
        defer { stroke = s }
        if s.edit != nil {
            apply(&s.edit!, to: c)
        } else if !inSpotlight(c) {
            return
        } else if s.visited.count > 1 {
            // Leaving the first cell turns the selection into a multi-selection.
            multiSelection = s.visited
        }
    }

    func endStroke() { stroke = nil }

    /// A pad digit with several cells selected. A note is added to every empty selected cell unless
    /// all of them have it, in which case it is removed from all. A big digit fills the empty ones,
    /// or, with none empty, clears that digit from them.
    private func applyToSelection(_ d: Int, asNote: Bool, kind: NoteKind) {
        guard !isComplete else { return }
        let cells = multiSelection.array
        let bit = Mask.bit(d)
        let adding = asNote ? cells.contains { values[$0] == 0 && notes[$0] & bit == 0 }
            : cells.contains { values[$0] == 0 }
        var e = Edit(digit: d, asNote: asNote, kind: kind, adding: adding)
        for c in cells { apply(&e, to: c) }
    }

    private func apply(_ e: inout Edit, to c: Int) {
        let bit = Mask.bit(e.digit)
        let changes: Bool
        if e.asNote {
            changes = values[c] == 0 && (notes[c] & bit != 0) != e.adding
        } else if isGiven(c) {
            changes = false
        } else {
            // Adding fills only empty cells; removing clears only this digit.
            changes = e.adding ? values[c] == 0 : values[c] == UInt8(e.digit)
        }
        guard changes, !isComplete, inSpotlight(c) else { return }
        if spotlightActive && !e.asNote && e.adding && !answersSpotlight(e.digit, at: c) { bounce(e.digit, at: c); return }
        if !e.pushedUndo { pushUndo(); e.pushedUndo = true }
        if e.asNote {
            notes[c] ^= bit
            if e.adding { setNoteKind(e.kind, at: c) }
        } else if e.adding {
            writeValue(e.digit, at: c)
        } else {
            values[c] = 0
            refreshAutoComplete()
        }
    }

    /// Picking a mode on the one-pad switch. Notes or Center with selected cells that have notes also
    /// redraws their notes that way, so the button toggles the cells' style (undoably).
    func choosePadMode(_ m: PadMode) {
        padMode = m
        guard m != .digits, !isComplete else { return }
        let cells = selectedCells.filter { values[$0] == 0 && notes[$0] != 0 && noteKind($0) != m.noteKind }
        guard !cells.isEmpty else { return }
        pushUndo()
        for c in cells { setNoteKind(m.noteKind, at: c) }
    }

    func noteKind(_ c: Int) -> NoteKind {
        centeredNotes.contains(c) ? .center : autoNotes.contains(c) ? .auto : .grid
    }

    /// Whether the cell's notes are drawn centered right now.
    func drawsCentered(_ c: Int) -> Bool {
        switch noteKind(c) {
        case .grid: false
        case .center: true
        case .auto: notes[c].nonzeroBitCount <= 3
        }
    }

    private func setNoteKind(_ k: NoteKind, at c: Int) {
        centeredNotes.remove(c); autoNotes.remove(c)
        switch k {
        case .grid: break
        case .center: centeredNotes.insert(c)
        case .auto: autoNotes.insert(c)
        }
    }

    /// Adding a note also sets how the cell draws its notes.
    func toggleNote(_ d: Int, at c: Int, kind: NoteKind = .grid) {
        guard !isComplete, values[c] == 0, inSpotlight(c) else { return }
        pushUndo()
        notes[c] ^= Mask.bit(d)
        if notes[c] & Mask.bit(d) != 0 { setNoteKind(kind, at: c) }
    }

    func erase() {
        guard !isComplete, !autoCompleting else { return }
        let cells = selectedCells.filter { !isGiven($0) && (values[$0] != 0 || notes[$0] != 0) }
        guard !cells.isEmpty else { return }
        pushUndo()
        for c in cells {
            if values[c] != 0 { values[c] = 0 } else { notes[c] = 0 }
        }
        refreshAutoComplete()
    }

    /// Fills every empty cell with all candidates that don't conflict with placed values.
    func fillNotes() {
        guard !isComplete else { return }
        pushUndo()
        // Cells that had no notes get the Manual / Auto notation; cells with notes keep theirs.
        let kind = Prefs.noteNotation.kind
        for c in 0..<81 where values[c] == 0 && notes[c] == 0 { setNoteKind(kind, at: c) }
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

    /// Flashes `d` when all nine are on the board with no row, column or box repeated.
    /// Judged from what the player sees, not the solution, so it never gives away a mistake.
    private func flashIfCompleted(_ d: Int) {
        let cells = (0..<81).filter { values[$0] == UInt8(d) }
        guard cells.count == 9,
              Set(cells.map { $0 / 9 }).count == 9,
              Set(cells.map { $0 % 9 }).count == 9,
              Set(cells.map { $0 / 27 * 3 + $0 % 9 / 3 }).count == 9 else { return }
        for c in cells { flashes[c] += 1 }
        digitsCompleted += 1
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
        untracked = true
        canAutoComplete = false
        selected = nil
        armed = nil
        lastDigit = nil
        for p in placements {
            values[p.cell] = UInt8(p.digit)
            notes[p.cell] = 0
            // Flash just this cell rather than highlighting every cell with the digit.
            flashes[p.cell] += 1
            flashIfCompleted(p.digit)
            // Slow enough to watch each cell fill in.
            if animated { try? await Task.sleep(for: .milliseconds(500)) }
        }
        autoCompleting = false
        untracked = false
        checkComplete()
    }

    #if DEBUG
    /// Test hook: fill every empty cell from the solution except the last `leaving` ones.
    func debugPrefill(leaving: Int, wrong: Bool) {
        let empties = (0..<81).filter { values[$0] == 0 }
        untracked = true
        for c in empties.dropLast(leaving) { values[c] = UInt8(solution[c]) }
        if wrong, let c = empties.first { values[c] = UInt8(solution[c] % 9 + 1) }
        untracked = false
        refreshAutoComplete()
    }
    #endif

    // MARK: Drills

    private func loadDrillTargets() {
        guard let drill else { return }
        Task {
            drillTargets = await Task.detached(priority: .userInitiated) { drill.targets() }.value
            checkDrill()
        }
    }

    /// The target the player has carried out: its placements made and its eliminations gone from
    /// the notes (or the cell filled with a different digit).
    var drillFoundStep: Step? {
        drillTargets.first { s in
            (spotlight?.accepts(s) ?? true)
                && s.placements.allSatisfy { values[$0.cell] == UInt8($0.digit) }
                && s.eliminations.allSatisfy { e in
                    values[e.cell] == 0 ? notes[e.cell] & Mask.bit(e.digit) == 0 : values[e.cell] != UInt8(e.digit)
                }
        }
    }

    private func checkDrill() {
        guard drill != nil, drillState == .searching, drillFoundStep != nil else { return }
        drillState = .found
        coach = nil
        closeSegment()
    }

    // MARK: Spotlight

    /// A question of a campaign lesson round.
    var isLesson: Bool {
        if case .lesson = campaign?.step { return true }
        return false
    }

    /// The spotlight still limits moves: until its question is answered.
    var spotlightActive: Bool { spotlight != nil && drill != nil && drillState == .searching }

    /// Whether the player may act on a cell (always, unless a spotlight leaves it out).
    func inSpotlight(_ c: Int) -> Bool { !spotlightActive || spotlight!.cells.contains(c) }

    /// The answers to the spotlight's question.
    var spotlightTargets: [Step] { spotlight.map { sp in drillTargets.filter(sp.accepts) } ?? [] }

    /// Arms the named digit or selects the named cell, and shows the intro for an exact question.
    private func prepareSpotlight() {
        guard let sp = spotlight, drillState == .searching else { return }
        if let c = sp.cell { selected = c }
        if let d = sp.digit, sp.cell == nil { armed = ArmedDigit(digit: d, small: false, kind: .grid) }
        if let intro = sp.intro { coach = .intro(intro) }
    }

    private func answersSpotlight(_ d: Int, at c: Int) -> Bool {
        spotlightTargets.contains { $0.placements.contains(Candidate(c, d)) }
    }

    /// A move inside the spotlight that isn't the answer: say why and leave the board as it was. A
    /// wrong digit is a mistake; a right digit that wasn't asked for isn't.
    private func bounce(_ d: Int, at c: Int) {
        guard let sp = spotlight else { return }
        let board = Board(Grid(cells: values))
        let feedback = SpotlightFeedback.judge(digit: d, at: c, board: board, solution: solution, asked: sp.technique)
        if d != solution[c] { mistakes += 1; segment?.mistakes += 1 }
        coach = .feedback(feedback, cell: c)
        attempts += 1
    }

    // MARK: Hints

    /// First press computes a hint at the nudge level; later presses reveal more.
    func requestHint() {
        guard !isComplete else { return }
        if var h = hint {
            if let next = HintLevel(rawValue: h.level.rawValue + 1) { h.level = next; hint = h; noteHint(h) }
            return
        }
        coach = nil
        let result: Hint
        if spotlightActive, let target = spotlightTargets.first {
            result = .step(target, instances: 1)
        } else {
            result = HintEngine.hint(values: values, notes: notes, givens: givens, solution: solution,
                                     solver: solver, near: selected)
        }
        hintsUsed += 1
        let start: HintLevel
        switch result {
        case .step: start = .nudge
        default: start = .answer
        }
        hint = HintSession(hint: result, level: start)
        noteHint(hint!)
    }

    /// Applies what the current hint shows (fixes mistakes, restores notes or performs the step).
    func applyHint() {
        guard let h = hint else { return }
        pushUndo()
        applyingHint = true
        defer { applyingHint = false }
        switch h.hint {
        case .solved: break
        case .wrongValues(let cells):
            for c in cells { values[c] = 0 }
        case .missingCandidates(let cs):
            for c in cs { notes[c.cell] |= Mask.bit(c.digit) }
        case .step(let s, _):
            for e in s.eliminations { notes[e.cell] &= ~Mask.bit(e.digit) }
            for p in s.placements {
                values[p.cell] = UInt8(p.digit)
                notes[p.cell] = 0
                if Prefs.autoRemoveNotes {
                    for q in Geometry.peers[p.cell] { notes[q] &= ~Mask.bit(p.digit) }
                }
                selected = p.cell
                flashIfCompleted(p.digit)
            }
            checkComplete()
        }
        hint = nil
    }
}

// MARK: Technique tracking

extension Game {
    nonisolated static let bottleneckSolver = HumanSolver()

    /// The solver behind move tracking and hints: in a campaign game, only the techniques the
    /// level may need, so hints never point past what the chapter has taught.
    var solver: HumanSolver { campaign.map { HumanSolver(allowing: $0.allowed) } ?? Game.bottleneckSolver }

    /// Moves so far whose bottleneck was one of the campaign level's techniques.
    var focusUses: Int {
        guard let focus = campaign?.focus else { return 0 }
        return moves.filter { focus.contains($0.technique) }.count
    }

    /// Starts timing the first move (or, after a restore, the next one).
    fileprivate func startTracking() {
        progress = correctCount
        startSegment()
    }

    private var correctCount: Int { (0..<81).reduce(0) { $0 + (values[$1] != 0 && !isWrong($1) ? 1 : 0) } }

    /// Called whenever the values change. A new correct digit ends the move being worked on;
    /// any change in the correct digits starts the next one from the new position.
    fileprivate func trackProgress() {
        guard drill == nil else { return }
        let now = correctCount
        guard now != progress else { return }
        let advanced = now > progress
        progress = now
        if advanced && !untracked { closeSegment() } else { segment = nil }
        startSegment()
    }

    private func startSegment() {
        guard !isComplete else { segment = nil; return }
        if drill != nil, drillState != .searching { segment = nil; return }
        segment = Segment(start: elapsed(), values: (0..<81).map { isWrong($0) ? 0 : values[$0] },
                          drill: drill?.technique)
    }

    /// Records the move being worked on, crediting the cell the player filled: the easiest
    /// technique that places it directly, or else the hardest one needed on the way to it
    /// (`HumanSolver.placementTechnique`). Worked out in the background.
    fileprivate func closeSegment() {
        guard let s = segment else { return }
        segment = nil
        let at = elapsed()
        let applied = applyingHint
        let technique: Task<Technique?, Never>
        if let t = s.drill {
            technique = Task { t }
        } else {
            let filled = (0..<81).first { s.values[$0] == 0 && values[$0] != 0 && !isWrong($0) }
            let board = Board(Grid(cells: s.values))
            let solver = solver
            technique = Task.detached(priority: .utility) {
                filled.flatMap { solver.placementTechnique(board, cell: $0) } ?? solver.nextPlacementBottleneck(board)
            }
        }
        pendingMoves.append(Task { [weak self] in
            guard let t = await technique.value, let self else { return }
            self.moves.append(TechniqueMove(technique: t, seconds: max(0, at - s.start), at: at, mistakes: s.mistakes,
                                            hintLevel: s.hintLevel?.rawValue, applied: applied))
        })
    }

    /// A hint about the next step counts against the move being worked on.
    fileprivate func noteHint(_ h: HintSession) {
        guard case .step = h.hint else { return }
        // Read first: reading `segment` inside its own modify access is an exclusivity violation.
        guard var s = segment else { return }
        s.hintLevel = max(s.hintLevel ?? h.level, h.level)
        segment = s
    }

    /// Every move, once those still being computed are done, in the order they were made.
    func finishedMoves() async -> [TechniqueMove] {
        let pending = pendingMoves
        pendingMoves.removeAll()
        for t in pending { await t.value }
        return moves.sorted { $0.at < $1.at }
    }
}
