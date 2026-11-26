import Foundation
import Testing
@testable import SudokuCore

@Suite struct DrillTests {
    func mined(_ wanted: Set<Technique>, seed: UInt64) -> [Drill] {
        var rng = SplitMix64(seed: seed)
        var out: [Drill] = []
        for _ in 0..<40 {
            let (p, s) = Generator.makePuzzle(using: &rng)
            out += Drill.mine(p, solution: s, wanted: wanted, using: &rng)
        }
        return out
    }

    @Test func minedDrillsStartWithTheirTechnique() throws {
        let drills = mined([.hiddenSingleBox, .nakedSingle, .pointing, .nakedPair], seed: 7)
        #expect(drills.count > 20)
        for d in drills {
            #expect(d.step()?.technique == d.technique, "\(d.technique)")
            #expect(!d.targets().isEmpty)
        }
    }

    @Test func singlesDrillsMatchPlainCandidates() {
        for d in mined([.hiddenSingleBox, .hiddenSingleLine, .nakedSingle], seed: 11) {
            #expect(!d.showsNotes)
            #expect(Board(d.values).candidates == d.candidates, "notes-free drills need the plain candidates")
        }
    }

    @Test func codingRoundTrips() throws {
        let d = try #require(mined([.pointing], seed: 3).first)
        let back = try JSONDecoder().decode(Drill.self, from: JSONEncoder().encode(d))
        #expect(back == d)
    }

    @Test func transformsKeepTheMove() throws {
        var rng = SplitMix64(seed: 99)
        for d in mined([.pointing, .claiming, .nakedPair, .xWing, .xyWing], seed: 5) {
            let t = d.transformed(by: .random(using: &rng))
            #expect(t.step()?.technique == d.technique)
            guard case .unique(let sol) = BruteForce.analyze(t.puzzle) else { Issue.record("not unique"); continue }
            for c in 0..<81 {
                if t.values[c] != 0 { #expect(sol[c] == t.values[c]) } else { #expect(t.candidates[c] & Mask.bit(sol[c]) != 0) }
            }
        }
    }

    /// The bundled bank was mined with an older engine: make sure engine changes haven't broken it.
    @Test func bundledDrillsStillWork() throws {
        let url = URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "../../../App/Resources/Drills.json").standardized
        let drills = try JSONDecoder().decode([Drill].self, from: Data(contentsOf: url))
        #expect(drills.count > 500)
        var broken: [String] = []
        for d in drills where d.step()?.technique != d.technique {
            broken.append("\(d.technique.rawValue): \(d.values.string) → \(HumanSolver().nextStep(d.board)?.technique.rawValue ?? "nil")")
        }
        #expect(broken.isEmpty, "Re-mine with `sudokugen drills`: \(broken.prefix(5).joined(separator: "\n"))")
    }
}
