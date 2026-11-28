import Testing
@testable import SudokuCore

@Suite struct RemotePairTests {
    /// A drill position (from a player's report) whose 2/8 network has six cells. The old
    /// chain-based finder saw only the shortest chain through four of them, split r1c9's two
    /// eliminations into separate steps, and never reached r5c9.
    func board() -> Board {
        let vals = "9...7.34.4...5...61..4....9247615983591...46.836.4....71459.63.659.34...328167594"
        let notes: [String: String] = [
            "r1c2": "68", "r1c3": "25", "r1c4": "28", "r1c6": "16", "r1c9": "1258",
            "r2c2": "78", "r2c3": "23", "r2c4": "39", "r2c6": "139", "r2c7": "1278", "r2c8": "127",
            "r3c2": "678", "r3c3": "235", "r3c5": "28", "r3c6": "36", "r3c7": "278", "r3c8": "257",
            "r5c4": "37", "r5c5": "28", "r5c6": "238", "r5c9": "27",
            "r6c4": "79", "r6c6": "29", "r6c7": "127", "r6c8": "1257", "r6c9": "1257",
            "r7c6": "28", "r7c9": "28",
            "r8c4": "28", "r8c7": "1278", "r8c8": "127", "r8c9": "1278",
        ]
        let values = vals.map { UInt8($0.wholeNumberValue ?? 0) }
        var cands = [DigitMask](repeating: 0, count: 81)
        for (k, v) in notes {
            let rc = k.dropFirst().split(separator: "c").map { Int($0)! }
            cands[(rc[0] - 1) * 9 + rc[1] - 1] = v.reduce(0) { $0 | Mask.bit($1.wholeNumberValue!) }
        }
        return Board(values: values, candidates: cands, givens: CellSet((0..<81).filter { values[$0] != 0 }))
    }

    @Test func oneStepCoversTheWholeNetwork() throws {
        let b = board()
        let steps = HumanSolver().allSteps(b, technique: .remotePair)
        #expect(steps.count == 1)
        let step = try #require(steps.first)
        let r1c9 = 8, r5c9 = 44
        #expect(Set(step.eliminations) == [Candidate(r1c9, 2), Candidate(r1c9, 8), Candidate(r5c9, 2)])
        let network: Set<Int> = [3, 22, 40, 59, 62, 66]   // r1c4 r3c5 r5c5 r7c6 r7c9 r8c4
        #expect(Set(step.highlights.map(\.cell)) == network)
        // Remote Pair is Hard 1 now: a Finned X-Wing (Medium 1) is the easiest move here, and a
        // 2-String Kite comes first in solve order at Hard 1, so only the step itself is checked.
        #expect(HumanSolver().nextStep(b)?.technique == .finnedXWing)
    }

    @Test func eliminationsAreSound() throws {
        let b = board()
        let solution = try #require(BruteForce.solution(b.grid))
        for e in HumanSolver().allSteps(b, technique: .remotePair).flatMap(\.eliminations) {
            #expect(solution[e.cell] != e.digit, "\(e)")
        }
    }
}
