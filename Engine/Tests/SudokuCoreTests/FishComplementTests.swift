import Foundation
import Testing
@testable import SudokuCore

/// A size-n fish on a digit with U unsolved lines has a complement of size U - n (the other
/// orientation, the lines outside the base and cover) with the same eliminations. Below 2n
/// unsolved lines the complement is the smaller fish, and that's the one to report.
@Suite struct FishComplementTests {
    /// Positions from the HoDoKu comparison (`hodoku-compare.sh`), with no notes removed yet.
    func board(_ s: String) throws -> Board { Board(try #require(Grid(s.replacingOccurrences(of: "+", with: "")))) }

    func removals(_ b: Board, _ t: Technique, digit d: Int) -> Set<Candidate> {
        Set(HumanSolver().allSteps(b, technique: t).flatMap(\.eliminations).filter { $0.digit == d })
    }

    /// 9 is unsolved in five rows. Rows 2,3,4 confine it to columns 2,3,4, but that "Swordfish" is
    /// the X-Wing on columns 1,6 (rows 7,9) seen from the other side, with the same eliminations.
    @Test func swordfishWithFiveUnsolvedLinesIsAnXWing() throws {
        let b = try board("..+1.5+2+4.957..6+42+3+14....1+8..8...2..1+4+1.748..+9+2+26+4+1+9+57+83.+4..1.+3+2.71.2+4.9........+14.")
        #expect(removals(b, .swordfish, digit: 9).isEmpty)
        let xWing = removals(b, .xWing, digit: 9)
        #expect(xWing == Set([(7, 3), (7, 4), (9, 2), (9, 3), (9, 4)].map { Candidate(($0.0 - 1) * 9 + $0.1 - 1, 9) }))
    }

    /// 4 is unsolved in six rows. Rows 1,2,4,6 confine it to columns 4,6,7,9, but that "Jellyfish"
    /// is the X-Wing on columns 2,3 (rows 5,7) seen from the other side.
    @Test func jellyfishWithSixUnsolvedLinesIsAnXWing() throws {
        let b = try board(".3..6.......2+39.5.46.85.2...16.9.5.........1..57..3.6.....+8.179....4.........2.4.")
        #expect(removals(b, .jellyfish, digit: 4).isEmpty)
        let xWing = removals(b, .xWing, digit: 4)
        #expect(xWing == Set([(5, 4), (5, 6), (5, 7), (5, 9)].map { Candidate(($0.0 - 1) * 9 + $0.1 - 1, 4) }))
    }

    /// 9 is unsolved in seven columns, but this Sashimi Jellyfish's complement (rows 1,4,5) isn't a
    /// Swordfish: column 7 holds 9 only in the Jellyfish's cover rows, so the complement has an
    /// empty cover line. The Jellyfish is the real pattern here, and stays (a drill from the bank).
    @Test func jellyfishWhoseComplementIsNoFishStays() throws {
        let json = "{\"c\":\"13100002113100003000000000012912100012d00002c0001040000d81c00d811810c00010400000018200008410400000000018c10e18100008500000000000018410406216206400c10c0001060000000000a00b80b80000000000000280fb0e30000bc00d03c08601c02e0bb0a30b900000d03c18611c12e\",\"p\":\".3..8.42...2.7.5.8.......61.5..617...4.25.6.......8.1.3...2917...9.........7.....\",\"t\":\"sashimiJellyfish\",\"v\":\".3..8.427..2.7.5.8.....2.61.5..617...4.2576.......8.153...2917...9.........7.....\"}"
        let b = try JSONDecoder().decode(Drill.self, from: Data(json.utf8)).board
        #expect(removals(b, .sashimiJellyfish, digit: 9) == [Candidate(5 * 9 + 6, 9)])
        for t: Technique in [.xWing, .finnedXWing, .sashimiXWing, .swordfish, .finnedSwordfish, .sashimiSwordfish] {
            #expect(removals(b, t, digit: 9).isEmpty)
        }
    }
}
