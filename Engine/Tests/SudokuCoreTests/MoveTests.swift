import Foundation
import Testing
@testable import SudokuCore

@Suite struct MoveTests {
    let solver = HumanSolver()

    /// Positions along the solver's own path through a few random puzzles.
    func positions(seed: UInt64, puzzles: Int) -> [(Board, Grid)] {
        var rng = SplitMix64(seed: seed)
        var out: [(Board, Grid)] = []
        for _ in 0..<puzzles {
            let (p, s) = Generator.makePuzzle(using: &rng)
            var b = Board(p)
            for step in solver.solve(p).steps {
                out.append((b, s))
                b.apply(step)
            }
        }
        return out
    }

    @Test func everyMoveIsSound() {
        for (b, sol) in positions(seed: 11, puzzles: 6) {
            let moves = solver.allMoves(b)
            for m in moves.placements { #expect(sol[m.candidate.cell] == m.candidate.digit, "\(m.technique) \(m.candidate)") }
            for m in moves.eliminations { #expect(sol[m.candidate.cell] != m.candidate.digit, "\(m.technique) \(m.candidate)") }
            for m in moves.placements + moves.eliminations {
                #expect(m.technique == m.step.technique)
                #expect(m.techniques == m.techniques.sorted { $0.score < $1.score })
                #expect(Set(m.techniques).count == m.techniques.count)
            }
        }
    }

    @Test func includesTheSolversNextStep() {
        for (b, _) in positions(seed: 12, puzzles: 4) {
            guard let next = solver.nextStep(b), next.technique.difficulty <= .hard,
                  !solver.strategies.contains(where: { $0.technique == next.technique && $0.ranked }) else { continue }
            let moves = solver.allMoves(b)
            for p in next.placements { #expect(moves.placements.contains { $0.candidate == p && $0.technique == next.technique }) }
            for e in next.eliminations { #expect(moves.eliminations.contains { $0.candidate == e }) }
        }
    }

    @Test func fullHouseShowsOnceLabeledFullHouse() throws {
        let g = try #require(Grid(classic))
        let sol = try #require(BruteForce.solution(g))
        var cells = sol.cells
        cells[40] = 0
        let moves = solver.allMoves(Board(Grid(cells: cells)))
        #expect(moves.placements.count == 1)
        let m = try #require(moves.placement(at: 40))
        #expect(m.candidate.digit == sol[40])
        #expect(m.technique == .fullHouse)
        #expect(m.techniques.contains(.nakedSingle))
        #expect(m.techniques.contains(.hiddenSingleBox))
        #expect(m.techniques.contains(.hiddenSingleLine))
        // Its row and column hidden singles are the same step for that technique.
        #expect(moves.steps(of: .hiddenSingleLine).count == 1)
        #expect(moves.steps(of: .fullHouse).count == 1)
    }

    @Test func tierCapLeavesHarderTechniquesOut() {
        for (b, _) in positions(seed: 13, puzzles: 3) {
            let moves = solver.allMoves(b, upTo: .easy)
            #expect(moves.steps.allSatisfy { $0.technique.difficulty <= .easy })
        }
    }

    @Test func fastEnoughForEveryMove() {
        let ps = positions(seed: 14, puzzles: 10)
        let start = Date()
        for (b, _) in ps { _ = solver.allMoves(b) }
        let perPosition = Date().timeIntervalSince(start) / Double(ps.count)
        #expect(perPosition < 0.02, "\(perPosition * 1000) ms per position")
    }

    @Test func placementTechniqueCreditsTheFilledCell() throws {
        let g = try #require(Grid(classic))
        let b = Board(g)
        let moves = solver.allMoves(b)
        // A cell some technique places now gets that move's easiest technique.
        for m in moves.placements {
            #expect(solver.placementTechnique(b, cell: m.candidate.cell) == m.technique, "\(m.candidate) \(m.techniques)")
        }
        // Every empty cell gets a technique, never harder than solving on would need.
        for c in b.emptyCells {
            let t = try #require(solver.placementTechnique(b, cell: c))
            #expect(t != .bruteForce)
        }
        #expect(solver.placementTechnique(b, cell: 0) == nil) // a given
    }

    @Test func hintCountsInstancesAndPicksTheNearest() throws {
        let g = try #require(Grid(classic))
        let sol = try #require(BruteForce.solution(g))
        let givens = Board(g).givens
        guard case .step(let s, let n) = HintEngine.hint(values: g.cells, notes: nil, givens: givens, solution: sol) else {
            Issue.record("expected step"); return
        }
        let count = solver.allMoves(Board(g)).steps(of: s.technique).count
        #expect(n == count)
        if n > 1 {
            #expect(s.hintText(.nudge, instances: n).contains("\(n)"))
            #expect(s.hintText(.technique, instances: n).contains("\(n)"))
            // Selecting another instance's target makes the hint show that one.
            let other = try #require(solver.allMoves(Board(g)).steps(of: s.technique).last)
            let cell = other.targetCells.array[0]
            guard case .step(let near, _) = HintEngine.hint(values: g.cells, notes: nil, givens: givens, solution: sol, near: cell) else {
                Issue.record("expected step"); return
            }
            #expect(near.targetCells.contains(cell))
        }
    }
}

@Suite(.disabled(if: ProcessInfo.processInfo.environment["PROFILE_MOVES"] == nil)) struct MoveProfile {
    @Test func perStrategy() {
        var rng = SplitMix64(seed: 14)
        var times: [Technique: Double] = [:]
        let solver = HumanSolver()
        for _ in 0..<10 {
            let (p, _) = Generator.makePuzzle(using: &rng)
            var b = Board(p)
            for step in solver.solve(p).steps {
                for s in solver.strategies where !s.ranked {
                    let t = Date()
                    var out = StepCollector(findAll: true, exhaustive: true)
                    s.find(b, &out)
                    times[s.technique, default: 0] += Date().timeIntervalSince(t)
                }
                b.apply(step)
            }
        }
        for (t, v) in times.sorted(by: { $0.value > $1.value }).prefix(10) { print("PROFILE \(t) \(Int(v * 1000)) ms") }
    }
}
