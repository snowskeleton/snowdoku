import Testing
@testable import SudokuCore

let classic = "530070000600195000098000060800060003400803001700020006060000280000419005000080079"
let hardOnes = [
    "1.......2.9.4...5...6...7...5.9.3.......7.......85..4.7.....6...3...9.8...2.....1", // Easter Monster
    "..............3.85..1.2.......5.7.....4...1...9.......5......73..2.1........4...9", // 17-clue
    "8..........36......7..9.2...5...7.......457.....1...3...1....68..85...1..9....4..", // Inkala
    "4.....8.5.3..........7......2.....6.....8.4......1.......6.3.7.5..2.....1.4......",
]

@Suite struct BasicsTests {
    @Test func parseAndPrint() throws {
        let g = try #require(Grid(classic))
        #expect(g.givenCount == 30)
        #expect(Grid(g.string) == g)
        #expect(Grid("123") == nil)
    }

    @Test func cellSet() {
        var s = CellSet([0, 63, 64, 80])
        #expect(s.count == 4)
        #expect(s.array == [0, 63, 64, 80])
        s.remove(63)
        #expect(!s.contains(63))
        #expect(Geometry.peers[0].count == 20)
        #expect(Geometry.commonPeers(CellSet([0, 8])).count == 7)
    }

    @Test func combinations() {
        var n = 0
        forEachCombination(9, 3) { _ in n += 1; return true }
        #expect(n == 84)
    }
}

@Suite struct BruteForceTests {
    @Test func uniqueSolutions() throws {
        for p in [classic] + hardOnes {
            let g = try #require(Grid(p))
            guard case .unique(let s) = BruteForce.analyze(g) else { Issue.record("not unique: \(p)"); continue }
            #expect(s.isComplete && s.isConsistent)
            for c in 0..<81 where g[c] != 0 { #expect(s[c] == g[c]) }
        }
    }

    @Test func detectsMultipleAndNone() {
        #expect(BruteForce.analyze(Grid()) == .multiple)
        var bad = Grid(classic)!
        bad[2] = 5 // duplicate 5 in row 1
        #expect(BruteForce.analyze(bad) == .none)
    }

    @Test func randomGridsAreValid() {
        var rng = SplitMix64(seed: 42)
        for _ in 0..<20 {
            let g = BruteForce.randomFilledGrid(using: &rng)
            #expect(g.isComplete && g.isConsistent)
        }
    }
}

/// Checks every step against the known solution: placements must match it and no
/// elimination may remove a solution digit. This catches unsound technique logic.
func assertSound(_ puzzle: Grid, solution: Grid, solver: HumanSolver = HumanSolver(), sourceLocation: SourceLocation = #_sourceLocation) -> [Technique: Int] {
    var board = Board(puzzle)
    var used: [Technique: Int] = [:]
    var steps = 0
    while !board.isSolved && steps < 500 {
        steps += 1
        guard let step = solver.nextStep(board) else {
            let c = board.emptyCells[0]
            board.place(c, solution[c])
            continue
        }
        used[step.technique, default: 0] += 1
        for p in step.placements where p.digit != solution[p.cell] {
            Issue.record("\(step.technique.name) placed wrong \(p) in \(puzzle.string): \(step.explanation)", sourceLocation: sourceLocation)
            return used
        }
        for e in step.eliminations where e.digit == solution[e.cell] {
            Issue.record("\(step.technique.name) eliminated solution \(e) in \(puzzle.string): \(step.explanation)", sourceLocation: sourceLocation)
            return used
        }
        board.apply(step)
    }
    #expect(board.isSolved, sourceLocation: sourceLocation)
    #expect(board.grid == solution, sourceLocation: sourceLocation)
    return used
}

@Suite struct SoundnessTests {
    @Test func knownPuzzles() throws {
        for p in [classic] + hardOnes {
            let g = try #require(Grid(p))
            _ = assertSound(g, solution: BruteForce.solution(g)!)
        }
    }

    @Test func generatedPuzzles() {
        var rng = SplitMix64(seed: 2026)
        var used: [Technique: Int] = [:]
        for _ in 0..<300 {
            let (p, s) = Generator.makePuzzle(using: &rng)
            for (t, n) in assertSound(p, solution: s) { used[t, default: 0] += n }
        }
        #expect(used.count > 20, "expected broad technique coverage, got \(used.keys.map(\.name))")
    }

    /// Each strategy alone, in exhaustive find-all mode (what drills use), on many mid-solve positions.
    @Test func everyStrategyFindAll() {
        var rng = SplitMix64(seed: 7)
        let solver = HumanSolver()
        for _ in 0..<25 {
            let (p, s) = Generator.makePuzzle(using: &rng)
            var board = Board(p)
            var guardCount = 0
            while !board.isSolved && guardCount < 200 {
                guardCount += 1
                for strat in solver.strategies {
                    // Exhaustive is a superset of plain find-all, so this checks both.
                    var out = StepCollector(findAll: true, exhaustive: true)
                    strat.find(board, &out)
                    for step in out.steps {
                        for e in step.eliminations where e.digit == s[e.cell] {
                            Issue.record("\(step.technique.name) unsound: \(e) — \(step.explanation)")
                        }
                        for pl in step.placements where pl.digit != s[pl.cell] {
                            Issue.record("\(step.technique.name) unsound placement: \(pl) — \(step.explanation)")
                        }
                    }
                }
                guard let step = solver.nextStep(board) else { break }
                board.apply(step)
            }
        }
    }
}

@Suite struct GeneratorTests {
    @Test func makesUniqueMinimalPuzzles() {
        var rng = SplitMix64(seed: 1)
        for sym in Symmetry.allCases {
            let (p, s) = Generator.makePuzzle(symmetry: sym, using: &rng)
            #expect(BruteForce.analyze(p) == .unique(s))
            for c in 0..<81 where p[c] != 0 {
                #expect(p[c] == p[sym.orbit(c).first { $0 != c } ?? c] || p[sym.orbit(c).first { $0 != c } ?? c] != 0)
            }
        }
    }

    @Test func deterministicWithSeed() {
        var a = SplitMix64(seed: 99), b = SplitMix64(seed: 99)
        #expect(Generator.makePuzzle(using: &a).puzzle == Generator.makePuzzle(using: &b).puzzle)
    }

    @Test func transformsPreserveRating() throws {
        var rng = SplitMix64(seed: 5)
        let g = try #require(Grid(hardOnes[1]))
        let base = Rater.rate(g)!
        for _ in 0..<3 {
            let t = GridTransform.random(using: &rng)
            let tg = t.apply(g)
            #expect(tg != g)
            let r = try #require(Rater.rate(tg))
            #expect(r.hardest.difficulty == base.hardest.difficulty)
        }
    }
}

@Suite struct HintTests {
    @Test func flagsWrongValuesThenGivesStep() throws {
        let g = try #require(Grid(classic))
        let sol = BruteForce.solution(g)!
        var values = g.cells
        let empty = values.firstIndex(of: 0)!
        values[empty] = UInt8(sol[empty] % 9 + 1)
        guard case .wrongValues(let w) = HintEngine.hint(values: values, notes: nil, givens: Board(g).givens, solution: sol) else {
            Issue.record("expected wrong value"); return
        }
        #expect(w == [empty])
        guard case .step(let s, _) = HintEngine.hint(values: g.cells, notes: nil, givens: Board(g).givens, solution: sol) else {
            Issue.record("expected step"); return
        }
        #expect(s.technique.difficulty == .beginner)
        #expect(!s.hintText(.technique).isEmpty)
    }
}

@Suite struct BottleneckTests {
    let solver = HumanSolver()

    @Test func solvedBoardHasNone() throws {
        let g = try #require(Grid(classic))
        let solved = try #require(BruteForce.solution(g))
        #expect(solver.nextPlacementBottleneck(Board(solved)) == nil)
    }

    @Test func easyStartNeedsOnlyASingle() throws {
        let g = try #require(Grid(classic))
        let t = try #require(solver.nextPlacementBottleneck(Board(g)))
        #expect(t.difficulty == .beginner)
    }

    /// Replaying a solve one placement at a time (values only, as a player's board is seen), the
    /// hardest bottleneck along the way is the puzzle's rated hardest technique.
    @Test func replayFindsTheHardestTechnique() throws {
        let g = try #require(Grid("...165...6.....7......93.........3.98.19...7...5..7.1.........61.8.3...4..95.4.3."))
        let log = solver.solve(g)
        var values = g.cells
        var hardest = try #require(solver.nextPlacementBottleneck(Board(g)))
        for p in log.steps.flatMap(\.placements) {
            values[p.cell] = UInt8(p.digit)
            if let t = solver.nextPlacementBottleneck(Board(Grid(cells: values))), t.score > hardest.score { hardest = t }
        }
        let rated = try #require(log.steps.map(\.technique).max { $0.score < $1.score })
        #expect(hardest == rated)
    }
}
