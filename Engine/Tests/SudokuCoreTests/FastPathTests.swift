import Testing
@testable import SudokuCore

/// The generator's shortcuts must give the same answers as the plain way of doing things.
@Suite struct FastPathTests {
    /// Removing clues from a unique puzzle: "is there a solution that changes a removed cell?"
    /// agrees with counting solutions, for single cells and for symmetric groups of cells.
    @Test func otherSolutionMatchesCounting() {
        var rng = SplitMix64(seed: 11)
        var nonUnique = 0
        for _ in 0..<40 {
            let solution = BruteForce.randomFilledGrid(using: &rng)
            var puzzle = solution
            var order = Array(0..<81)
            order.shuffle(using: &rng)
            for cell in order where puzzle[cell] != 0 {
                let orbit = Symmetry.rotational90.orbit(cell).filter { puzzle[$0] != 0 }
                for c in orbit { puzzle[c] = 0 }
                let other = BruteForce.hasOtherSolution(puzzle, than: solution, differingIn: orbit)
                #expect(other == !BruteForce.hasUniqueSolution(puzzle))
                if other {
                    nonUnique += 1
                    for c in orbit { puzzle[c] = solution[c] }
                }
            }
        }
        #expect(nonUnique > 100)
    }

    /// Rating for a tier gives the full rating when the puzzle is in that tier, and nil otherwise.
    @Test func tierRatingMatchesFullRating() {
        var rng = SplitMix64(seed: 5)
        var seen = Set<Difficulty>()
        for _ in 0..<120 {
            let (p, s) = Generator.makePuzzle(using: &rng)
            let full = Rater.rate(p, solution: s)
            seen.insert(full.difficulty)
            for tier in Difficulty.allCases where tier != .extreme {
                let quick = Rater.rate(p, solution: s, ifIn: tier)
                #expect(quick == (full.difficulty == tier ? full : nil), "\(p.string) as \(tier.name)")
            }
        }
        #expect(seen.count >= 5)
    }

    /// The same for levels, including bumped puzzles, which land on a tier's first level.
    @Test func levelRatingMatchesFullRating() {
        var rng = SplitMix64(seed: 8)
        var seen = Set<Level>()
        for _ in 0..<60 {
            let (p, s) = Generator.makePuzzle(using: &rng)
            let full = Rater.rate(p, solution: s)
            seen.insert(full.level)
            for level in Level.allCases where level != .extreme {
                let quick = Rater.rate(p, solution: s, ifIn: level)
                #expect(quick == (full.level == level ? full : nil), "\(p.string) as \(level.name)")
            }
        }
        #expect(seen.count >= 6)
    }

    /// The per-digit cell sets stay in step with the candidate masks through a whole solve.
    @Test func digitCellsTrackCandidates() {
        var rng = SplitMix64(seed: 3)
        let solver = HumanSolver()
        for _ in 0..<20 {
            let (p, s) = Generator.makePuzzle(using: &rng)
            var board = Board(p)
            for step in solver.solve(board, solution: s).steps {
                board.apply(step)
                for d in 1...9 {
                    let plain = CellSet((0..<81).filter { board.candidates[$0] & Mask.bit(d) != 0 })
                    #expect(board.cells(with: d) == plain)
                    for h in 0..<27 {
                        let mask = Geometry.houses[h].indices.reduce(UInt16(0)) { m, k in
                            board.has(Geometry.houses[h][k], d) ? m | 1 << UInt16(k) : m
                        }
                        #expect(board.positionMask(d, h) == mask)
                    }
                }
            }
        }
    }
}
