/// A training position: a mid-solve board where the very next logical move is `technique`.
///
/// Drills are mined offline with `sudokugen drills` and bundled with the app. The candidates are
/// the solver's own at that moment (including eliminations from earlier steps), so the player
/// sees exactly the position the solver saw and no easier move exists.
public struct Drill: Hashable, Sendable {
    public var technique: Technique
    /// The original givens.
    public var puzzle: Grid
    /// Givens plus every digit placed so far.
    public var values: Grid
    /// Candidates of every empty cell (0 for filled cells).
    public var candidates: [DigitMask]

    public init(technique: Technique, puzzle: Grid, values: Grid, candidates: [DigitMask]) {
        self.technique = technique
        self.puzzle = puzzle
        self.values = values
        self.candidates = candidates
    }

    public init(technique: Technique, puzzle: Grid, board: Board) {
        self.init(technique: technique, puzzle: puzzle, values: board.grid, candidates: board.candidates)
    }

    public var givens: CellSet { CellSet((0..<81).filter { puzzle[$0] != 0 }) }
    public var board: Board { Board(values: values.cells, candidates: candidates, givens: givens) }

    /// Singles are practiced by scanning, without notes; everything else needs candidates on the board.
    public var showsNotes: Bool { technique.difficulty > .beginner }

    /// The move the solver would make next. Nil only if the engine changed since the drill was mined.
    public func step(solver: HumanSolver = HumanSolver()) -> Step? {
        let s = solver.nextStep(board)
        return s?.technique == technique ? s : nil
    }

    /// Every instance of the technique in the position; finding any of them completes the drill.
    public func targets(solver: HumanSolver = HumanSolver()) -> [Step] {
        solver.allSteps(board, technique: technique)
    }

    /// The same drill relabeled and reshuffled, so repeats don't look like repeats.
    public func transformed(by t: GridTransform) -> Drill {
        let map = t.cellMap
        var cands = [DigitMask](repeating: 0, count: 81)
        for src in 0..<81 {
            var m: DigitMask = 0
            for d in Mask.digits(candidates[src]) { m |= Mask.bit(Int(t.digitMap[d])) }
            cands[map[src]] = m
        }
        return Drill(technique: technique, puzzle: t.apply(puzzle), values: t.apply(values), candidates: cands)
    }

    /// Finds positions in a solve where the next move is one of `wanted`, at most one per technique,
    /// picked at random among that technique's occurrences.
    ///
    /// For singles, only positions reached by singles alone qualify, since those drills are shown
    /// without notes and the player's own candidates must match the solver's.
    public static func mine<R: RandomNumberGenerator>(_ puzzle: Grid, solution: Grid, wanted: Set<Technique>,
                                                      solver: HumanSolver = HumanSolver(),
                                                      using rng: inout R) -> [Drill] {
        var board = Board(puzzle)
        var found: [Technique: [Board]] = [:]
        var onlySingles = true
        var level = Level.beginner1
        while !board.isSolved, let step = solver.nextStep(board, level: level) {
            level = max(level, step.level)
            let t = step.technique
            if wanted.contains(t) && (t.difficulty > .beginner || onlySingles) {
                found[t, default: []].append(board)
            }
            if t.difficulty > .beginner { onlySingles = false }
            board.apply(step)
        }
        guard board.isSolved, board.grid == solution else { return [] }
        return found.sorted { $0.key < $1.key }.compactMap { t, boards in
            boards.randomElement(using: &rng).map { Drill(technique: t, puzzle: puzzle, board: $0) }
        }
    }
}

extension GridTransform {
    /// cellMap[old cell] = new cell.
    public var cellMap: [Int] {
        var map = [Int](repeating: 0, count: 81)
        for r in 0..<9 {
            for c in 0..<9 {
                map[rowOrder[r] * 9 + colOrder[c]] = transpose ? c * 9 + r : r * 9 + c
            }
        }
        return map
    }
}

// MARK: Compact coding

/// Encoded as `{"t": technique, "p": givens, "v": values, "c": candidates}`, where the grids are
/// 81-character strings and candidates are three hex digits per cell.
extension Drill: Codable {
    enum CodingKeys: String, CodingKey { case t, p, v, c }

    public init(from decoder: Decoder) throws {
        let k = try decoder.container(keyedBy: CodingKeys.self)
        technique = try k.decode(Technique.self, forKey: .t)
        func grid(_ key: CodingKeys) throws -> Grid {
            guard let g = Grid(try k.decode(String.self, forKey: key)) else {
                throw DecodingError.dataCorruptedError(forKey: key, in: k, debugDescription: "Not an 81-cell grid")
            }
            return g
        }
        puzzle = try grid(.p)
        values = try grid(.v)
        guard let cands = CandidateHex.decode(try k.decode(String.self, forKey: .c)) else {
            throw DecodingError.dataCorruptedError(forKey: .c, in: k, debugDescription: "Expected 243 hex digits")
        }
        candidates = cands
    }

    public func encode(to encoder: Encoder) throws {
        var k = encoder.container(keyedBy: CodingKeys.self)
        try k.encode(technique, forKey: .t)
        try k.encode(puzzle.string, forKey: .p)
        try k.encode(values.string, forKey: .v)
        try k.encode(CandidateHex.encode(candidates), forKey: .c)
    }
}

/// Candidates of all 81 cells as three hex digits per cell (the bundled drill and campaign files).
enum CandidateHex {
    static func encode(_ candidates: [DigitMask]) -> String {
        let digits = Array("0123456789abcdef")
        return candidates.map { m in String([digits[Int(m >> 8 & 0xF)], digits[Int(m >> 4 & 0xF)], digits[Int(m & 0xF)]]) }.joined()
    }

    static func decode(_ s: String) -> [DigitMask]? {
        let hex = Array(s.utf8)
        guard hex.count == 243 else { return nil }
        return (0..<81).map { i in
            hex[i * 3..<i * 3 + 3].reduce(0) { acc, ch in acc << 4 | DigitMask(ch <= 57 ? ch - 48 : ch - 87) }
        }
    }
}
