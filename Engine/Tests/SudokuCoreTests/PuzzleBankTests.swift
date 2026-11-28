import Dispatch
import Foundation
import Testing
@testable import SudokuCore

@Suite struct PuzzleBankTests {
    @Test func lineRoundTrips() throws {
        var rng = SplitMix64(seed: 21)
        for _ in 0..<10 {
            let (p, s) = Generator.makePuzzle(using: &rng)
            let b = BankedPuzzle(puzzle: p, rating: Rater.rate(p, solution: s))
            #expect(BankedPuzzle(line: Substring(b.line)) == b)
        }
        #expect(BankedPuzzle(line: "not a puzzle") == nil)
    }

    @Test func dailyPickIsDeterministic() throws {
        var rng = SplitMix64(seed: 5)
        let pool = (0..<5).map { _ in
            let (p, s) = Generator.makePuzzle(using: &rng)
            return BankedPuzzle(puzzle: p, rating: Rater.rate(p, solution: s))
        }
        let a = try #require(Daily.pick(from: pool, seed: 123))
        #expect(Daily.pick(from: pool, seed: 123) == a)
        #expect(a.solution.isComplete && a.solution.isConsistent)
        #expect(BruteForce.hasUniqueSolution(a.puzzle))
    }

    /// The bank was rated with an older engine: make sure its stored ratings (and so its tiers
    /// and the dailies drawn from them) still match what the engine says now.
    @Test func bundledRatingsStillMatch() throws {
        let url = URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "../../../App/Resources/Puzzles.tsv").standardized
        let bank = BankedPuzzle.parse(try String(contentsOf: url, encoding: .utf8))
        let tiers = Dictionary(grouping: bank, by: \.difficulty).mapValues(\.count)
        let levels = Dictionary(grouping: bank, by: \.level).mapValues(\.count)
        for d in Difficulty.allCases {
            #expect((tiers[d] ?? 0) >= 500, "\(d.name) has \(tiers[d] ?? 0) puzzles")
        }
        for l in Level.allCases {
            #expect((levels[l] ?? 0) > 0, "\(l.name) has no puzzles")
            // Dailies draw from the first `Daily.poolSize` puzzles of each level, so a level must
            // never shrink below it.
            #expect((levels[l] ?? 0) >= Daily.poolSize[l] ?? 0, "\(l.name) is smaller than its daily pool")
        }
        let mismatches = Locked<[String]>([])
        DispatchQueue.concurrentPerform(iterations: bank.count) { i in
            let b = bank[i]
            let now = Rater.rate(b.puzzle)
            if now != b.rating {
                mismatches.with { $0.append("\(b.puzzle.string): \(b.rating.hardest.rawValue) → \(now?.hardest.rawValue ?? "invalid")") }
            }
        }
        let bad = mismatches.with { $0 }
        #expect(bad.isEmpty, "\(bad.count) ratings changed; re-rate with `sudokugen bank App/Resources/Puzzles.tsv`: \(bad.prefix(5).joined(separator: "\n"))")
    }
}

private final class Locked<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: T
    init(_ v: T) { value = v }
    func with<R>(_ f: (inout T) -> R) -> R { lock.lock(); defer { lock.unlock() }; return f(&value) }
}
