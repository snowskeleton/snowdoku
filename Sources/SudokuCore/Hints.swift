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
    case step(Step)
}

public enum HintEngine {
    /// Produces a hint for the player's current state.
    /// - Parameters:
    ///   - values: the player's entered digits (0 = empty), including givens.
    ///   - notes: the player's pencil marks, or nil to use computed candidates.
    public static func hint(values: [UInt8], notes: [DigitMask]?, givens: CellSet, solution: Grid,
                            solver: HumanSolver = HumanSolver()) -> Hint {
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
        if let s = solver.nextStep(board) { return .step(s) }
        let c = board.emptyCells.min { board.candidates[$0].nonzeroBitCount < board.candidates[$1].nonzeroBitCount }!
        return .step(Step(.bruteForce, placements: [Candidate(c, solution[c])], houses: Geometry.housesOfCell[c],
                          highlights: [Highlight(c, solution[c], .pattern)],
                          explanation: "No known technique applies here. \(Geometry.cellName(c)) is \(solution[c])."))
    }
}

extension Step {
    /// Text for a given hint level.
    public func hintText(_ level: HintLevel) -> String {
        switch level {
        case .nudge:
            return placements.isEmpty
                ? "There's a candidate you can eliminate. Look for a \(technique.difficulty.name.lowercased())-level move."
                : "There's a digit you can place. Look for a \(technique.difficulty.name.lowercased())-level move."
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
