/// How much of a singles drill is narrowed down for the player, from one exact question to the whole
/// board. Lessons fade from `exact` to `open`, so a beginner first answers a question with one answer
/// and then learns to find the same pattern unaided.
public enum SpotlightLevel: Int, Codable, CaseIterable, Sendable {
    /// One house and digit ("Where does the 5 go in this box?"), or one cell ("Which digit fits here?").
    case exact
    /// One house, or a naked single's box: any instance there counts.
    case area
    /// One digit anywhere on the board ("Place a 5").
    case digit
    /// The whole board: any instance counts.
    case open
}

/// The part of a drill position the player is asked about: the lit cells, and the digit or cell the
/// question names. Only moves inside it count, so every question has a definite answer and a wrong
/// move gets precise feedback.
public struct Spotlight: Hashable, Codable, Sendable {
    public var technique: Technique
    public var level: SpotlightLevel
    /// Cells the player may act on; the rest of the board is context.
    public var cells: CellSet
    /// The house the question is about, if any.
    public var house: Int?
    /// The digit the question names, if any.
    public var digit: Int?
    /// The cell the question names, if any.
    public var cell: Int?

    public init(technique: Technique, level: SpotlightLevel, cells: CellSet, house: Int? = nil, digit: Int? = nil, cell: Int? = nil) {
        self.technique = technique
        self.level = level
        self.cells = cells
        self.house = house
        self.digit = digit
        self.cell = cell
    }

    static let allCells = CellSet(0..<81)

    /// The techniques a spotlight can scope: singles, whose instances are each one placement.
    public static func supports(_ t: Technique) -> Bool { CampaignChapter.singles.contains(t) }

    /// The level actually used for a technique: Full House has no digit to name and nothing between
    /// its house and the whole board; a naked single names no digit.
    public static func effective(_ level: SpotlightLevel, for t: Technique) -> SpotlightLevel {
        switch (t, level) {
        case (.fullHouse, .area), (.fullHouse, .digit): .open
        case (.nakedSingle, .digit): .open
        default: level
        }
    }

    /// A spotlight on one of `targets` (the technique's instances in the position), picked by `pick`
    /// among them. Nil when there are no targets or the technique isn't a single.
    public static func make(_ technique: Technique, level: SpotlightLevel, targets: [Step],
                            pick: (Int) -> Int = { _ in 0 }) -> Spotlight? {
        guard supports(technique), !targets.isEmpty else { return nil }
        let level = effective(level, for: technique)
        let focus = targets[pick(targets.count) % targets.count]
        guard let p = focus.placements.first else { return nil }
        let h = focus.houses.first
        switch (technique, level) {
        case (_, .open):
            return Spotlight(technique: technique, level: .open, cells: allCells)
        case (.fullHouse, _):
            guard let h else { return nil }
            return Spotlight(technique: technique, level: .exact, cells: Geometry.houseSets[h], house: h, cell: p.cell)
        case (.nakedSingle, .exact):
            return Spotlight(technique: technique, level: .exact, cells: CellSet([p.cell]), cell: p.cell)
        case (.nakedSingle, _):
            let box = 18 + Geometry.boxOf[p.cell]
            return Spotlight(technique: technique, level: .area, cells: Geometry.houseSets[box], house: box)
        case (_, .exact):
            guard let h else { return nil }
            return Spotlight(technique: technique, level: .exact, cells: Geometry.houseSets[h], house: h, digit: p.digit)
        case (_, .area):
            guard let h else { return nil }
            return Spotlight(technique: technique, level: .area, cells: Geometry.houseSets[h], house: h)
        case (_, .digit):
            return Spotlight(technique: technique, level: .digit, cells: allCells, digit: p.digit)
        }
    }

    /// Whether a step answers the question: its placement is inside, with the named digit and cell.
    public func accepts(_ s: Step) -> Bool {
        guard s.technique == technique, let p = s.placements.first else { return false }
        if !cells.contains(p.cell) { return false }
        if let digit, p.digit != digit { return false }
        if let cell, p.cell != cell { return false }
        return true
    }

    /// The question, short enough for one header line.
    public var prompt: String {
        let where_ = house.map { Geometry.kind($0) } .map { k -> String in
            switch k { case .row: "this row"; case .column: "this column"; case .box: "this box" }
        } ?? "the board"
        switch (technique, level) {
        case (.fullHouse, .exact): return "Which digit is missing from \(where_)?"
        case (.fullHouse, _): return "Find a house with one empty cell"
        case (.nakedSingle, .exact): return "Which digit fits in this cell?"
        case (.nakedSingle, .area): return "Which cell here has just one option?"
        case (.nakedSingle, _): return "Find a cell where only one digit fits"
        case (_, .exact): return "Where does the \(digit ?? 0) go in \(where_)?"
        case (_, .area): return "Which digit has one spot in \(where_)?"
        case (.hiddenSingleBox, .digit): return "Find a box with one spot for a \(digit ?? 0)"
        case (_, .digit): return "Find a row or column with one spot for a \(digit ?? 0)"
        case (.hiddenSingleBox, _): return "Find a digit with one spot in a box"
        default: return "Find a digit with one spot in a row or column"
        }
    }

    /// A short explanation shown before an exact question: the rule the question practices. Kept
    /// to two lines or so, since it floats over the bottom of the board.
    public var intro: String? {
        guard level == .exact else { return nil }
        let d = digit ?? 0
        switch technique {
        case .fullHouse:
            return "Each row, column and box holds 1 to 9 once. This \(houseWord) has one gap: which digit is missing?"
        case .hiddenSingleBox:
            return "Each \(d) nearby rules out its row and column in this box. Find the one cell left."
        case .nakedSingle:
            return "Rule out the digits this cell's row, column and box already have. One is left."
        case .hiddenSingleLine:
            let others = houseWord == "row" ? "column" : "row"
            return "Each \(d) on the board rules out its \(others) and box. Find the one cell left in this \(houseWord)."
        default:
            return nil
        }
    }

    private var houseWord: String {
        guard let house else { return "house" }
        switch Geometry.kind(house) { case .row: return "row"; case .column: return "column"; case .box: return "box" }
    }
}

/// What to tell a player whose move inside a spotlight wasn't the answer.
public enum SpotlightFeedback: Hashable, Sendable {
    /// The digit already appears in a house of the cell: `seenAt` is where.
    case conflict(digit: Int, house: Int, seenAt: Int)
    /// A wrong digit with no visible conflict (it's ruled out by deeper logic).
    case wrong(digit: Int)
    /// The right digit, made by a different single than the one asked for.
    case otherTechnique(found: Technique, asked: Technique)
    /// The right digit, but nothing on the board forces it yet.
    case notForced(digit: Int)
    /// A right move, but not the one the question names (another cell, house or digit).
    case notAsked

    public var message: String {
        switch self {
        case let .conflict(d, h, _): "There's already a \(d) in \(Geometry.houseName(h))."
        case let .wrong(d): "\(d) doesn't go there."
        case let .otherTechnique(found, asked): "Correct, but that's a \(found.name). This one asks for a \(asked.name)."
        case let .notForced(d): "\(d) is right, but nothing forces it yet. Look for a cell or spot with only one option."
        case .notAsked: "That's right, but it's not what this question asks."
        }
    }

    /// Judges placing `digit` at `cell` (a move that wasn't accepted) in `board`, the position before
    /// the move. `solution` tells right from wrong.
    public static func judge(digit: Int, at cell: Int, board: Board, solution: Grid, asked: Technique,
                             solver: HumanSolver = HumanSolver()) -> SpotlightFeedback {
        if solution[cell] != digit {
            for h in Geometry.housesOfCell[cell] {
                if let seen = Geometry.houses[h].first(where: { $0 != cell && board.values[$0] == UInt8(digit) }) {
                    return .conflict(digit: digit, house: h, seenAt: seen)
                }
            }
            return .wrong(digit: digit)
        }
        let singles: [Technique] = [.fullHouse, .hiddenSingleBox, .hiddenSingleLine, .nakedSingle]
        let justified = singles.filter { t in
            solver.allSteps(board, technique: t).contains { $0.placements.contains(Candidate(cell, digit)) }
        }
        if justified.contains(asked) { return .notAsked }
        if let t = justified.first { return .otherTechnique(found: t, asked: asked) }
        return .notForced(digit: digit)
    }
}
