import Testing
@testable import SudokuCore

/// A position in HoDoKu's library format: the grid ("+" before a digit marks a placed, non-given
/// cell) and its eliminations as digit-row-column triples ("965" removes 9 from r6c5).
func libraryBoard(_ grid: String, _ eliminations: String) -> Board {
    var values: [UInt8] = [], givens: [Int] = [], placed = false
    for ch in grid {
        if ch == "+" { placed = true; continue }
        let v = UInt8(ch.wholeNumberValue ?? 0)
        if v != 0 && !placed { givens.append(values.count) }
        values.append(v)
        placed = false
    }
    var cands = Board(Grid(cells: values)).candidates
    for code in eliminations.split(separator: " ") {
        let n = code.compactMap(\.wholeNumberValue)
        cands[(n[1] - 1) * 9 + n[2] - 1] &= ~Mask.bit(n[0])
    }
    return Board(values: values, candidates: cands, givens: CellSet(givens))
}
@Suite struct MissingRectangleTests {
    /// A Hard+ bank position in HoDoKu's library format: r5c5, r5c9 and r6c9 are {7,9}, and r6c5
    /// is {7,8} because an earlier step removed its 9 (the "965" in the eliminations list).
    /// HoDoKu's Uniqueness Test 1 (missing candidates allowed) removes 7 from r6c5.
    func board() -> Board {
        libraryBoard(".+5+362.....6+4.+1+5.3+2.92+3+47.+5+6+9+87+5+36.+2.5+4+61.2+38.3+2+1+4..5+6.4+7+8+25+1+693+6+35..42..+2+1+9.+6+3.4+5",
                     "117 965 785")
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

    /// Type 3 with a single extra digit: r5c9 and r6c9 are {2,6,7} on a {27} rectangle, so one of
    /// them is 6. That virtual 6 and r4c9 {3,6} lock 3 and 6 in column 9 and in box 6, so 3 goes
    /// from r9c9 and r4c7. (Found by HoDoKu; we used to require two different extra digits.)
    @Test func type3WithOneExtraDigit() {
        let b = libraryBoard("+16+84+2+39+759+52..+7+83+47+3+45+9+8+6+21..927......3..9.....1.3+4.+9.+2...4..68+3.+6+7.+24.9.....62..",
                             "441 841 148 548 452 852 855 158 558 862 772 177 577 591 792 194 894")
        var out = StepCollector(findAll: true)
        UniqueRectangle(type: 3).find(b, &out)
        let removed = Set(out.steps.flatMap(\.eliminations))
        #expect(removed.contains(Candidate(Geometry.cell(3, 6), 3)))
        #expect(removed.contains(Candidate(Geometry.cell(8, 8), 3)))
    }

    /// Type 3 whose locked set is large (the roof extras 2/4/5/6 with four cells of box 2): seen
    /// from the other side, r2c5 is the only place left for 7, so 2 and 4 go from it.
    @Test func type3WithALargeSubset() {
        let b = libraryBoard(".3+7...5.16.+5..+13.+81.89......+8+971.....+1+3..9+8.776+23..+1.9.5+1..4...+37+61+9+2+48+58.4+5...16",
                             "411 375 978")
        var out = StepCollector(findAll: true)
        UniqueRectangle(type: 3).find(b, &out)
        let removed = Set(out.steps.flatMap(\.eliminations))
        #expect(removed.contains(Candidate(Geometry.cell(1, 4), 2)) && removed.contains(Candidate(Geometry.cell(1, 4), 4)))
    }
}
