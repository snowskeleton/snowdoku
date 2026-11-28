import Testing
@testable import SudokuCore

/// ALS and Sue de Coq patterns HoDoKu found where our detectors used to miss them
/// (positions from `Engine/Tools/hodoku-compare.sh`, in HoDoKu's library format).
@Suite struct ALSTests {
    /// `:0000:x:<grid>:<deleted candidates>::`: placed digits carry a `+`, deleted candidates
    /// are `<digit><row><col>`.
    func board(_ line: String) -> Board {
        let parts = line.split(separator: ":", omittingEmptySubsequences: false)
        var values: [UInt8] = [], givens: [Int] = [], placed = false
        for ch in parts[3] {
            if ch == "+" { placed = true; continue }
            let v = UInt8(ch.wholeNumberValue ?? 0)
            if v != 0 && !placed { givens.append(values.count) }
            values.append(v)
            placed = false
        }
        var cands = Board(Grid(cells: values)).candidates
        for code in parts[4].split(separator: " ") {
            let n = code.compactMap(\.wholeNumberValue)
            cands[(n[1] - 1) * 9 + n[2] - 1] &= ~Mask.bit(n[0])
        }
        return Board(values: values, candidates: cands, givens: CellSet(givens))
    }

    func cell(_ name: String) -> Int {
        let rc = name.dropFirst().split(separator: "c").map { Int($0)! }
        return (rc[0] - 1) * 9 + rc[1] - 1
    }

    /// Every step of the technique, checked against the solution; returns them.
    func soundSteps(_ b: Board, _ t: Technique, sourceLocation: SourceLocation = #_sourceLocation) throws -> [Step] {
        let solution = try #require(BruteForce.solution(b.grid), sourceLocation: sourceLocation)
        let steps = HumanSolver().allSteps(b, technique: t)
        for e in steps.flatMap(\.eliminations) {
            #expect(solution[e.cell] != e.digit, "\(t) removes the solution digit \(e)", sourceLocation: sourceLocation)
        }
        return steps
    }

    @Test func doublyLinkedALSXZ() throws {
        // A = r2c4589 {23567}, B = r1237c7 {25678}, restricted commons 5 and 6: both are locked
        // sets, so 2 leaves r1c8 and r8c7 (seeing all of A's or B's 2s) and 8 leaves r8c7.
        let b = board(":0000:x:..5+96+1..4+419..8.....+254..+91+25+147.9...+4...9+1.2+9.....4..+5+9+4..2.1673.......12....3..:::")
        let steps = try soundSteps(b, .alsXZ)
        let removed = Set(steps.flatMap(\.eliminations))
        #expect(removed.isSuperset(of: [Candidate(cell("r1c8"), 2), Candidate(cell("r8c7"), 2), Candidate(cell("r8c7"), 8)]))
        #expect(steps.contains { $0.explanation.hasPrefix("Doubly linked ALS-XZ") })
    }

    @Test func largeALS() throws {
        // A = r13456789c1, an ALS of eight cells, with B = r3678c3 {12489} (restricted commons 2
        // and 8) removes 8 from r4c3.
        let b = board(":0000:x:..7.+29.........1+7..4..783.2.3..4+1.27.26..+7.+3....+2.35......3..+15.8.7+15.43.1.......:511 611 811 414 514 614 521 523 531 533::")
        let removed = Set(try soundSteps(b, .alsXZ).flatMap(\.eliminations))
        #expect(removed.contains(Candidate(cell("r4c3"), 8)))
    }

    @Test func sueDeCoqWithDigitsOutsideTheIntersection() throws {
        // r1c79 {1789} with r1c46 {147} in the row and r13c8 {389} in the box: 4 and 3 aren't in
        // the intersection, so each needs one more cell. Removes 3 from r3c9.
        let b = board(":0000:x:.3..6.......2+39.5.46.85.2...16.9.5.........1..57..3.6.....+8.179....4.........2.4.:417 419::")
        let removed = Set(try soundSteps(b, .sueDeCoq).flatMap(\.eliminations))
        #expect(removed.contains(Candidate(cell("r3c9"), 3)))
    }

    @Test func sueDeCoqWithADigitInBothParts() throws {
        // r8c23 {123478} with r8c458 {23679} in the row and r78c1,r9c23 {1468} in the box: 6 is in
        // neither the intersection nor only one part, so it can go once in each. Removes 9 from r8c7.
        let b = board(":0000:x:+56+7+8+9+4+32+141....5+8+9.+98+1.+5+64+7....7..9+47..41..+5+3...58.+7+16....4...8........59..35..72:326 626 241 341 242 842 643 646 253 256 271 371 373 673 676 976 281 381 683 686 986::")
        let steps = try soundSteps(b, .sueDeCoq)
        #expect(Set(steps.flatMap(\.eliminations)).contains(Candidate(cell("r8c7"), 9)))
    }

    @Test func sueDeCoqWithLargerParts() throws {
        // r79c6 {14679} with r25c6 {479} in the column and r9c45 {168} in the box. Removes 4 from r8c6.
        let b = board(":0000:x:.9......4+3+57.2.6+1+8.+6+4...93.+7...62..+35.+314...+66...38....3+6...8.5.......6.475...3+29:514 515 516 534 983 584::")
        let removed = Set(try soundSteps(b, .sueDeCoq).flatMap(\.eliminations))
        #expect(removed.contains(Candidate(cell("r8c6"), 4)))
    }
}
