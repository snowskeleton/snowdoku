import Foundation
import Testing
@testable import SudokuCore

/// The ideas borrowed from HoDoKu: score-based tiers, tabled forcing chains, and the extra techniques.
@Suite struct HoDoKuIdeasTests {
    static func extremes(_ n: Int) throws -> [Grid] {
        let url = URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "../../Data/extreme-puzzles.txt").standardized
        return try String(contentsOf: url, encoding: .utf8).split(separator: "\n").prefix(n).compactMap { Grid(String($0)) }
    }

    @Test func longSolvesAreBumpedOneTier() {
        let quick = Rating(hardest: .xWing, techniqueLevel: .medium1, totalScore: 900, counts: [.xWing: 1], stepCount: 50)
        #expect(quick.difficulty == .medium)
        let grind = Rating(hardest: .xWing, techniqueLevel: .medium1, totalScore: 2000, counts: [.xWing: 12], stepCount: 50)
        #expect(grind.difficulty == .hard, "one tier up, never two")
        let master = Rating(hardest: .alsXZ, techniqueLevel: .master2, totalScore: 50_000, counts: [.alsXZ: 1], stepCount: 50)
        #expect(master.difficulty == .master, "long Master solves don't become Extreme")
    }

    /// Chain-mode tables only ever follow single links, so every conclusion has one premise.
    @Test func chainTablesAreChains() throws {
        let g = try #require(Self.extremes(1).first)
        let b = Board(g)
        for c in b.emptyCells.prefix(10) {
            for d in Mask.digits(b.candidates[c]) {
                let t = ImplicationTable(b, assume: Literal(c, d, on: true), net: false)
                for l in t.order.dropFirst() { #expect(t.premisesOf(l).count == 1) }
            }
        }
    }

    /// Forcing chains and nets on hard puzzles: sound, and each one explains itself with its chains.
    @Test func forcingStepsAreSoundAndExplained() throws {
        let forcing: Set<Technique> = [.cellForcingChain, .unitForcingChain, .forcingContradiction, .forcingNet]
        var seen = 0
        for g in try Self.extremes(6) {
            let s = try #require(BruteForce.solution(g))
            var board = Board(g)
            for _ in 0..<300 where !board.isSolved {
                guard let step = HumanSolver().nextStep(board) else {
                    let c = board.emptyCells[0]
                    board.place(c, s[c])
                    continue
                }
                for e in step.eliminations { #expect(e.digit != s[e.cell], "\(step.explanation)") }
                for p in step.placements { #expect(p.digit == s[p.cell], "\(step.explanation)") }
                if forcing.contains(step.technique) && step.complexity < 1000 {
                    seen += 1
                    #expect(step.explanation.contains("→"), "\(step.explanation)")
                    #expect(!step.links.isEmpty)
                }
                board.apply(step)
            }
        }
        #expect(seen > 0)
    }

    /// A wider find-all sweep for the newer, cheap strategies.
    @Test func newStrategiesFindAll() {
        let strategies: [any Strategy] = [LockedSubset(size: 2), LockedSubset(size: 3), AvoidableRectangle2(),
                                          SimpleColoring(wrap: true), ChainStrategy(mode: .discontinuous),
                                          GeneralFish(kind: .franken)]
        var rng = SplitMix64(seed: 31)
        var found: [Technique: Int] = [:]
        for _ in 0..<120 {
            let (p, s) = Generator.makePuzzle(using: &rng)
            var board = Board(p)
            var n = 0
            while !board.isSolved && n < 200 {
                n += 1
                for strat in strategies {
                    var out = StepCollector(findAll: true)
                    strat.find(board, &out)
                    found[strat.technique, default: 0] += out.steps.count
                    for step in out.steps {
                        for e in step.eliminations { #expect(e.digit != s[e.cell], "\(step.explanation)") }
                        for pl in step.placements { #expect(pl.digit == s[pl.cell], "\(step.explanation)") }
                    }
                }
                guard let step = HumanSolver().nextStep(board) else { break }
                board.apply(step)
            }
        }
        #expect((found[.lockedPair] ?? 0) > 0)
        #expect((found[.discontinuousNiceLoop] ?? 0) > 0)
    }
}
