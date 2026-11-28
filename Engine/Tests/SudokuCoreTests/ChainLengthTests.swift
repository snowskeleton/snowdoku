import Testing
@testable import SudokuCore

/// Long chains cost extra in a rating and, long enough, count as a harder level.
@Suite struct ChainLengthTests {
    static func chain(_ t: Technique, links n: Int) -> Step {
        let link = ChainLink(from: [Candidate(0, 1)], to: [Candidate(1, 1)], isStrong: true)
        return Step(t, links: Array(repeating: link, count: n), explanation: "")
    }

    @Test func longChainsScoreAndRateHigher() {
        #expect(Self.chain(.xChain, links: 9).score == Technique.xChain.score)
        #expect(Self.chain(.xChain, links: 15).score == Technique.xChain.score + 60)
        #expect(Self.chain(.xChain, links: 13).level == .expert3)
        #expect(Self.chain(.xChain, links: 14).level == .master1)
        #expect(Self.chain(.xyChain, links: 13).level == .master1)
        #expect(Self.chain(.aic, links: 18).level == .master1)
        #expect(Self.chain(.aic, links: 19).level == .master3)
        #expect(Self.chain(.groupedAIC, links: 60).level == .master3, "a chain is never Extreme")
        let fish = Step(.xWing, links: Self.chain(.xChain, links: 30).links, explanation: "")
        #expect(fish.score == Technique.xWing.score && fish.level == Technique.xWing.level, "only chains")
    }

    @Test func ratingUsesTheHardestStep() {
        let r = Rater.rating(from: [Self.chain(.xChain, links: 5), Self.chain(.xyChain, links: 15)])
        #expect(r.hardest == .xyChain && r.techniqueLevel == .master1 && r.difficulty == .master)
        #expect(Rater.rating(from: [Self.chain(.xyChain, links: 5)]).techniqueLevel == .expert3)
        let b = BankedPuzzle(puzzle: Grid(String(repeating: ".", count: 81))!, rating: r)
        #expect(b.line.hasSuffix("\tmaster1"))
        #expect(BankedPuzzle(line: Substring(b.line)) == b)
    }
}
