import Testing
@testable import SudokuCore

/// Long chains cost extra in a rating and, long enough, count as a harder tier.
@Suite struct ChainLengthTests {
    static func chain(_ t: Technique, links n: Int) -> Step {
        let link = ChainLink(from: [Candidate(0, 1)], to: [Candidate(1, 1)], isStrong: true)
        return Step(t, links: Array(repeating: link, count: n), explanation: "")
    }

    @Test func longChainsScoreAndRateHigher() {
        #expect(Self.chain(.xChain, links: 9).score == Technique.xChain.score)
        #expect(Self.chain(.xChain, links: 15).score == Technique.xChain.score + 60)
        #expect(Self.chain(.xChain, links: 13).difficulty == .expert)
        #expect(Self.chain(.xChain, links: 14).difficulty == .master)
        #expect(Self.chain(.xyChain, links: 13).difficulty == .master)
        #expect(Self.chain(.groupedAIC, links: 60).difficulty == .master, "a chain is never Extreme")
        let fish = Step(.xWing, links: Self.chain(.xChain, links: 30).links, explanation: "")
        #expect(fish.score == Technique.xWing.score && fish.difficulty == Technique.xWing.difficulty, "only chains")
    }

    @Test func ratingUsesTheHardestStep() {
        let r = Rater.rating(from: [Self.chain(.xChain, links: 5), Self.chain(.xyChain, links: 15)])
        #expect(r.hardest == .xyChain && r.hardestStep == .master && r.difficulty == .master)
        #expect(Rater.rating(from: [Self.chain(.xyChain, links: 5)]).hardestStep == nil)
        let b = BankedPuzzle(puzzle: Grid(String(repeating: ".", count: 81))!, rating: r)
        #expect(b.line.hasSuffix("\t6"))
        #expect(BankedPuzzle(line: Substring(b.line)) == b)
    }
}
