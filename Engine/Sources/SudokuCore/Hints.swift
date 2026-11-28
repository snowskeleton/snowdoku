/// Progressive hint levels, from a gentle nudge to the full answer.
public enum HintLevel: Int, CaseIterable, Comparable, Sendable {
    /// "There's something to find."
    case nudge
    /// Names the technique, not where it is.
    case technique
    /// Points at the houses/area to look in.
    case region
    /// Highlights the pattern cells.
    case pattern
    /// Shows the deduction.
    case answer

    public static func < (a: HintLevel, b: HintLevel) -> Bool { a.rawValue < b.rawValue }
}

public enum Hint: Sendable {
    case solved
    /// Cells whose entered value disagrees with the solution.
    case wrongValues([Int])
    /// The player removed a candidate that is actually the answer.
    case missingCandidates([Candidate])
    /// The next step, and how many distinct instances of its technique the position has
    /// (1 for chains and forcing, which aren't searched exhaustively).
    case step(Step, instances: Int)
}

public enum HintEngine {
    /// Produces a hint for the player's current state.
    /// - Parameters:
    ///   - values: the player's entered digits (0 = empty), including givens.
    ///   - notes: the player's pencil marks, or nil to use computed candidates.
    ///   - near: the selected cell, if any: when the next technique applies in several places,
    ///     the hint shows the one closest to it.
    public static func hint(values: [UInt8], notes: [DigitMask]?, givens: CellSet, solution: Grid,
                            solver: HumanSolver = HumanSolver(), near: Int? = nil) -> Hint {
        let wrong = (0..<81).filter { values[$0] != 0 && Int(values[$0]) != solution[$0] }
        if !wrong.isEmpty { return .wrongValues(wrong) }
        if !values.contains(0) { return .solved }

        var board = Board(Grid(cells: values))
        board = Board(values: values, candidates: board.candidates, givens: givens)
        if let notes {
            let missing = (0..<81).filter { values[$0] == 0 && notes[$0] != 0 && notes[$0] & Mask.bit(solution[$0]) == 0 }
            if !missing.isEmpty { return .missingCandidates(missing.map { Candidate($0, solution[$0]) }) }
            // Respect the player's eliminations: intersect computed candidates with their notes.
            let merged = (0..<81).map { notes[$0] == 0 ? board.candidates[$0] : board.candidates[$0] & notes[$0] }
            board = Board(values: values, candidates: merged, givens: givens)
        }
        if let s = solver.nextStep(board) { return instances(of: s, board, solver: solver, near: near) }
        let c = board.emptyCells.min { board.candidates[$0].nonzeroBitCount < board.candidates[$1].nonzeroBitCount }!
        return .step(Step(.bruteForce, placements: [Candidate(c, solution[c])], houses: Geometry.housesOfCell[c],
                          highlights: [Highlight(c, solution[c], .pattern)],
                          explanation: "No known technique applies here. \(Geometry.cellName(c)) is \(solution[c])."), instances: 1)
    }

    /// Counts the distinct instances of `step`'s technique and picks the one nearest `near`.
    /// Chains and forcing keep the solver's own (simplest) pick and count as one.
    static func instances(of step: Step, _ board: Board, solver: HumanSolver, near: Int?) -> Hint {
        guard let strategy = solver.strategies.first(where: { $0.technique == step.technique }), !strategy.ranked else {
            return .step(step, instances: 1)
        }
        var seen = Set<[Int]>()
        let all = solver.allSteps(board, technique: step.technique).filter { seen.insert($0.conclusionKey).inserted }
        guard all.count > 1 else { return .step(step, instances: 1) }
        guard let near else { return .step(step, instances: all.count) }
        func distance(_ s: Step) -> Int {
            s.targetCells.array.map { c in abs(c / 9 - near / 9) + abs(c % 9 - near % 9) }.min() ?? 99
        }
        let nearest = all.min { distance($0) < distance($1) } ?? step
        return .step(nearest, instances: all.count)
    }
}

extension Step {
    /// Text for a given hint level. `instances` is how many places the technique applies
    /// (`Hint.step`); when it's more than one, the nudge and technique levels say so.
    public func hintText(_ level: HintLevel, instances: Int = 1) -> String {
        let tier = difficulty.name.lowercased()
        switch level {
        case .nudge where instances > 1:
            return placements.isEmpty
                ? "One \(tier)-level move eliminates candidates in \(instances) places. Can you find one?"
                : "One \(tier)-level move places a digit in \(instances) places. Can you find one?"
        case .technique where instances > 1:
            return "Try a \(technique.name). There are \(instances) on the board. \(technique.summary)"
        case .nudge:
            return placements.isEmpty
                ? "There's a candidate you can eliminate. Look for a \(tier)-level move."
                : "There's a digit you can place. Look for a \(tier)-level move."
        case .technique:
            return "Try a \(technique.name). \(technique.summary)"
        case .region:
            let hs = houses.isEmpty ? Geometry.sharedHouses(patternCells.array) : houses
            if hs.isEmpty { return "Look around \(Geometry.cellsName(patternCells.array.prefix(3)))." }
            return "Look at \(Array(Set(hs)).sorted().map(Geometry.houseName).joined(separator: ", "))."
        case .pattern:
            return "Focus on these cells: \(Geometry.cellsName(patternCells.array))."
        case .answer:
            return explanation
        }
    }
}
