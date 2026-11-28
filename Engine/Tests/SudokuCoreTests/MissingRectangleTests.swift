import Testing
@testable import SudokuCore

@Suite struct MissingRectangleTests {
    /// A Hard+ bank position in HoDoKu's library format: r5c5, r5c9 and r6c9 are {7,9}, and r6c5
    /// is {7,8} because an earlier step removed its 9 (the "965" in the eliminations list).
    /// HoDoKu's Uniqueness Test 1 (missing candidates allowed) removes 7 from r6c5.
    func board() -> Board {
        let line = ".+5+362.....6+4.+1+5.3+2.92+3+47.+5+6+9+87+5+36.+2.5+4+61.2+38.3+2+1+4..5+6.4+7+8+25+1+693+6+35..42..+2+1+9.+6+3.4+5"
        var values: [UInt8] = [], givens: [Int] = [], placed = false
        for ch in line {
            if ch == "+" { placed = true; continue }
            let v = UInt8(ch.wholeNumberValue ?? 0)
            if v != 0 && !placed { givens.append(values.count) }
            values.append(v)
            placed = false
        }
        var cands = Board(Grid(cells: values)).candidates
        for (d, r, c) in [(1, 1, 7), (9, 6, 5), (7, 8, 5)] { cands[(r - 1) * 9 + c - 1] &= ~Mask.bit(d) }
        return Board(values: values, candidates: cands, givens: CellSet(givens))
    }

    @Test func findsTheType1() {
        let b = board()
        #expect(b.candidates[40] == Mask.from([7, 9]) && b.candidates[44] == Mask.from([7, 9]))
        #expect(b.candidates[53] == Mask.from([7, 9]) && b.candidates[49] == Mask.from([7, 8]))
        // The ordinary rectangles need both digits in every corner.
        for t in 1...6 {
            var out = StepCollector(findAll: true)
            UniqueRectangle(type: t).find(b, &out)
            #expect(!out.steps.contains { $0.eliminations.contains(Candidate(49, 7)) })
        }
        var out = StepCollector(findAll: true)
        UniqueRectangleMissing().find(b, &out)
        let step = out.steps.first { $0.eliminations == [Candidate(49, 7)] }
        #expect(step?.technique == .uniqueRectangleMissing)
        #expect(step?.explanation.contains("r6c5 has lost its 9") == true)
    }

    /// The same rectangle doesn't count when a given rules the missing digit out of the corner:
    /// then the swap could never have worked.
    @Test func ignoresDigitsBlockedByGivens() {
        let b = board()
        let rect = [40, 44, 49, 53]
        #expect(rectanglePairs(b, rect, missing: true).contains { $0 == (7, 9) })
        // Make r6c1, a peer of r6c5 outside the rectangle, a given 9.
        var values = b.values
        values[45] = 9
        let blocked = Board(values: values, candidates: b.candidates, givens: b.givens | CellSet([45]))
        #expect(!rectanglePairs(blocked, rect, missing: true).contains { $0 == (7, 9) })
        var out = StepCollector(findAll: true)
        UniqueRectangleMissing().find(blocked, &out)
        #expect(!out.steps.contains { $0.eliminations.contains(Candidate(49, 7)) })
    }
}
