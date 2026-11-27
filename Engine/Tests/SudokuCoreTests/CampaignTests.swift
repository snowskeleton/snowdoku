import Dispatch
import Foundation
import Testing
@testable import SudokuCore

@Suite struct CampaignTests {
    @Test func chaptersAreConsistent() {
        let ids = CampaignChapter.all.map(\.id)
        #expect(Set(ids).count == ids.count, "chapter ids are unique")
        var taught = Set<Technique>()
        for ch in CampaignChapter.all {
            #expect(taught.isDisjoint(with: ch.family), "\(ch.id) teaches something an earlier chapter did")
            taught.formUnion(ch.family)
            #expect(ch.cumulative.isSuperset(of: ch.family))
            #expect(ch.allowed(.spotlight).contains(ch.lead))
        }
        #expect(!taught.contains(.bruteForce))
    }

    @Test func puzzleRoundTripsThroughJSON() throws {
        let p = CampaignPuzzle(chapter: "pointing", kind: .spotlight, member: .pointing,
                               puzzle: Grid(String(repeating: ".", count: 80) + "1")!,
                               values: Grid(String(repeating: ".", count: 80) + "1")!,
                               candidates: Array(repeating: 0x1FF, count: 81), uses: 3, outside: [], totalScore: 99)
        let data = try JSONEncoder().encode(p)
        #expect(try JSONDecoder().decode(CampaignPuzzle.self, from: data) == p)
    }

    /// The bundled campaign was mined with an older engine: every puzzle must still be solvable
    /// with its kind's techniques, still need its chapter's, and still use them as often as stored.
    @Test func bundledCampaignStillWorks() throws {
        let url = URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "../../../App/Resources/Campaign.json").standardized
        let puzzles = try JSONDecoder().decode([CampaignPuzzle].self, from: Data(contentsOf: url))

        // Every chapter has a spotlight for every family member, a boss and endless. (Practice
        // or mixed may be missing where the miner found none; the app skips those steps.)
        let byChapter = Dictionary(grouping: puzzles, by: \.chapter)
        for ch in CampaignChapter.all {
            let list = byChapter[ch.id] ?? []
            for kind in [CampaignKind.boss, .endless] {
                #expect(list.contains { $0.kind == kind }, "\(ch.id) has no \(kind.rawValue) puzzles")
            }
            for m in ch.family {
                #expect(list.contains { $0.kind == .spotlight && $0.member == m }, "\(ch.id) has no spotlight for \(m.rawValue)")
            }
            let boss = list.filter { $0.kind == .boss }
            if let first = boss.first {
                #expect(boss.allSatisfy { $0.score <= first.score }, "\(ch.id)'s boss pool doesn't lead with its best")
            }
        }

        let problems = Locked<[String]>([])
        DispatchQueue.concurrentPerform(iterations: puzzles.count) { i in
            let p = puzzles[i]
            func bad(_ why: String) { problems.with { $0.append("\(p.chapter).\(p.kind.rawValue) \(p.puzzle.string): \(why)") } }
            guard let ch = CampaignChapter.named(p.chapter), ch.kinds.contains(p.kind) else { return bad("unknown chapter or kind") }
            if ch.capsClues(p.kind) && p.clueCount > CampaignKind.maxClues { bad("\(p.clueCount) clues") }
            if ch.allowed(p.kind, member: p.member).contains(where: \.assumesUniqueness), !BruteForce.hasUniqueSolution(p.puzzle) {
                return bad("not unique")
            }
            guard let a = p.analysis(), a.solved else { return bad("no longer solvable with its techniques") }
            if a.uses != p.uses || a.uses < 1 { bad("uses \(p.uses) → \(a.uses)") }
            if Set(a.outside) != Set(p.outside) { bad("outside \(p.outside.map(\.rawValue)) → \(a.outside.map(\.rawValue).sorted())") }
            if a.totalScore != p.totalScore { bad("score \(p.totalScore) → \(a.totalScore)") }
            let without = ch.allowed(p.kind, member: p.member).subtracting(ch.focusTechniques(p.kind, member: p.member))
            if HumanSolver(allowing: without).solve(p.board).solved { bad("no longer needs the chapter's technique") }
        }
        let found = problems.with { $0 }
        #expect(found.isEmpty, "\(found.count) campaign puzzles changed; re-merge or re-mine (see CLAUDE.md): \(found.prefix(5).joined(separator: "\n"))")
    }
}

private final class Locked<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: T
    init(_ v: T) { value = v }
    func with<R>(_ f: (inout T) -> R) -> R { lock.lock(); defer { lock.unlock() }; return f(&value) }
}
