/// Clue layouts. Symmetric puzzles look nicer; asymmetric ones are easier to make hard.
public enum Symmetry: String, CaseIterable, Codable, Sendable {
    case none, rotational180, rotational90, mirror, diagonal

    /// Cells that must be removed together with `cell`.
    public func orbit(_ cell: Int) -> [Int] {
        let r = cell / 9, c = cell % 9
        var s: Set<Int> = [cell]
        switch self {
        case .none: break
        case .rotational180: s.insert((8 - r) * 9 + (8 - c))
        case .rotational90:
            s.insert(c * 9 + (8 - r)); s.insert((8 - r) * 9 + (8 - c)); s.insert((8 - c) * 9 + r)
        case .mirror: s.insert(r * 9 + (8 - c))
        case .diagonal: s.insert(c * 9 + r)
        }
        return Array(s)
    }
}

public struct GeneratedPuzzle: Hashable, Sendable, Codable {
    public var puzzle: Grid
    public var solution: Grid
    public var rating: Rating

    public init(puzzle: Grid, solution: Grid, rating: Rating) {
        self.puzzle = puzzle
        self.solution = solution
        self.rating = rating
    }
}

public enum Generator {
    /// Makes a random puzzle with a unique solution by removing clues from a random full grid
    /// until no more can be removed (minimal with respect to the symmetry).
    public static func makePuzzle<R: RandomNumberGenerator>(symmetry: Symmetry = .none, using rng: inout R) -> (puzzle: Grid, solution: Grid) {
        let solution = BruteForce.randomFilledGrid(using: &rng)
        var puzzle = solution
        var order = Array(0..<81)
        order.shuffle(using: &rng)
        var tried = [Bool](repeating: false, count: 81)
        for cell in order where !tried[cell] {
            let orbit = symmetry == .none ? [cell] : symmetry.orbit(cell)
            for c in orbit { tried[c] = true; puzzle[c] = 0 }
            // The puzzle was unique before, so only a solution that changes a removed cell can appear.
            if BruteForce.hasOtherSolution(puzzle, than: solution, differingIn: orbit) {
                for c in orbit { puzzle[c] = solution[c] }
            }
        }
        return (puzzle, solution)
    }

    /// Generates puzzles until one matches the requested constraints.
    /// - Parameters:
    ///   - difficulty: required tier (nil = any). Puzzles are then rated with the full technique
    ///     set by `Rater.rate(_:solution:ifIn:)`, which stops early on ones that overshoot.
    ///   - level: required level (`Rating.level`), instead of a tier.
    ///   - requiring: a technique the solve must use (nil = any).
    ///   - solver: rates puzzles when no difficulty is given.
    public static func generate<R: RandomNumberGenerator>(difficulty: Difficulty? = nil,
                                                          level: Level? = nil,
                                                          requiring: Technique? = nil,
                                                          symmetry: Symmetry = .none,
                                                          maxAttempts: Int = 10_000,
                                                          solver: HumanSolver = HumanSolver(),
                                                          using rng: inout R) -> GeneratedPuzzle? {
        for _ in 0..<maxAttempts {
            let (p, s) = makePuzzle(symmetry: symmetry, using: &rng)
            let rated = level.map { Rater.rate(p, solution: s, ifIn: $0) }
                ?? difficulty.map { Rater.rate(p, solution: s, ifIn: $0) } ?? Rater.rate(p, solution: s, solver: solver)
            guard let rating = rated else { continue }
            if let requiring, rating.counts[requiring] == nil { continue }
            return GeneratedPuzzle(puzzle: p, solution: s, rating: rating)
        }
        return nil
    }
}

/// A validity- and difficulty-preserving relabeling of a grid. Applying a random transform to a
/// stored puzzle yields a puzzle that looks different but needs exactly the same techniques.
public struct GridTransform: Hashable, Sendable, Codable {
    /// digitMap[d] = new digit for old digit d (index 0 unused).
    public var digitMap: [UInt8]
    /// New row i comes from old row rowOrder[i].
    public var rowOrder: [Int]
    public var colOrder: [Int]
    public var transpose: Bool

    public static let identity = GridTransform(digitMap: Array(0...9).map(UInt8.init), rowOrder: Array(0..<9), colOrder: Array(0..<9), transpose: false)

    public static func random<R: RandomNumberGenerator>(using rng: inout R) -> GridTransform {
        func lineOrder() -> [Int] {
            var bands = [0, 1, 2]; bands.shuffle(using: &rng)
            return bands.flatMap { b -> [Int] in var r = [0, 1, 2]; r.shuffle(using: &rng); return r.map { b * 3 + $0 } }
        }
        var digits = Array(1...9).map(UInt8.init); digits.shuffle(using: &rng)
        return GridTransform(digitMap: [0] + digits, rowOrder: lineOrder(), colOrder: lineOrder(), transpose: Bool.random(using: &rng))
    }

    public func apply(_ g: Grid) -> Grid {
        var out = Grid()
        for r in 0..<9 {
            for c in 0..<9 {
                let src = rowOrder[r] * 9 + colOrder[c]
                let dst = transpose ? c * 9 + r : r * 9 + c
                out.cells[dst] = digitMap[Int(g.cells[src])]
            }
        }
        return out
    }
}

public enum Daily {
    /// Deterministic seed for a calendar day; everyone gets the same daily puzzle offline.
    public static func seed(year: Int, month: Int, day: Int) -> UInt64 {
        var rng = SplitMix64(seed: UInt64(year * 10_000 + month * 100 + day) &* 0x2545_F491_4F6C_DD1D)
        return rng.next()
    }
}
