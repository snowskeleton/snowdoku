import Foundation
import SudokuCore

/// One thing to mine: puzzles of a kind for a chapter (and, for spotlights, one family member).
struct CampaignTarget: Hashable, Sendable, CustomStringConvertible {
    var chapter: CampaignChapter
    var kind: CampaignKind
    var member: Technique?

    var allowed: Set<Technique> { chapter.allowed(kind, member: member) }
    var focus: Set<Technique> { chapter.focusTechniques(kind, member: member) }
    /// Without the focus techniques the puzzle must be unsolvable, so it really needs them.
    var withoutFocus: Set<Technique> { allowed.subtracting(focus) }

    /// Spotlights from the Notes part on start mid-solve with notes, right before the first use;
    /// so do the later chapters' context and mixed puzzles, to spare the player a long run of singles.
    var startsMidSolve: Bool {
        switch kind {
        case .spotlight: chapter.part >= 2
        case .context, .mixed: chapter.part >= 5
        default: false
        }
    }

    var description: String { "\(chapter.id).\(kind.rawValue)" + (member.map { ".\($0.rawValue)" } ?? "") }

    /// Every target for a chapter: a spotlight per family member, then the other kinds.
    static func all(for ch: CampaignChapter, kinds: [CampaignKind]) -> [CampaignTarget] {
        kinds.flatMap { k -> [CampaignTarget] in
            guard ch.kinds.contains(k) else { return [] }
            return k == .spotlight ? ch.family.map { CampaignTarget(chapter: ch, kind: k, member: $0) }
                            : [CampaignTarget(chapter: ch, kind: k, member: nil)]
        }
    }
}

/// A scored candidate puzzle.
struct Mined: Sendable {
    var puzzle: Grid
    var analysis: CampaignAnalysis
    var score: Double
}

enum CampaignMiner {
    /// Checks a puzzle against a target and scores it. Puzzles that don't qualify still get a
    /// (lower) fitness, so a climb can find its way from an unsuitable seed to a suitable one.
    static func evaluate(_ g: Grid, _ t: CampaignTarget) -> (fitness: Double, mined: Mined?) {
        // Too many clues is unrealistic; steer back toward real-looking puzzles.
        let clues = (0..<81).filter { g[$0] != 0 }.count
        let excess = t.chapter.capsClues(t.kind) ? max(0, clues - CampaignKind.maxClues) : 0
        let a = CampaignAnalysis.analyze(Board(g), allowed: t.allowed, focus: t.focus, routine: t.chapter.routine)
        guard a.solved else { return (-1_000 - Double(a.stuckEmpty), nil) }
        // Sound techniques that solve a puzzle prove it unique; only uniqueness techniques
        // (which assume it) need the brute-force check, which is slow on sparse grids.
        if t.allowed.contains(where: \.assumesUniqueness) && !BruteForce.hasUniqueSolution(g) { return (-10_000, nil) }
        guard a.uses >= 1 else { return (-500, nil) }
        // A mid-solve start shows only what comes after the cut.
        let outside = t.startsMidSolve ? a.outsideAfterFirstUse : a.outside
        if t.kind == .mixed && outside.count < t.chapter.mixedVariety {
            return (-200 + Double(outside.count) * 50 + Double(a.uses), nil)
        }
        if HumanSolver(allowing: t.withoutFocus).solve(Board(g)).solved { return (-100 + Double(a.uses), nil) }
        let s = t.kind.score(uses: a.uses, outside: outside.count, totalScore: a.totalScore)
        if excess > 0 { return (s - 50 * Double(excess), nil) }
        return (s, Mined(puzzle: g, analysis: a, score: s))
    }

    /// A random puzzle that's as sparse as the target's allowed techniques permit: a random solved
    /// grid with clues removed in random order while the allowed techniques still solve it.
    static func sparse<R: RandomNumberGenerator>(_ t: CampaignTarget, using rng: inout R) -> Grid {
        let solver = HumanSolver(allowing: t.allowed)
        let solution = BruteForce.randomFilledGrid(using: &rng)
        var g = solution
        for cell in (0..<81).shuffled(using: &rng) {
            let v = g[cell]
            g[cell] = 0
            if !solver.solve(Board(g)).solved { g[cell] = v }
        }
        return g
    }

    /// One solution-preserving change: drop a clue, add one from the solution, or both.
    static func mutate<R: RandomNumberGenerator>(_ g: Grid, solution: Grid, using rng: inout R) -> Grid {
        var g = g
        let clues = (0..<81).filter { g[$0] != 0 }
        let empty = (0..<81).filter { g[$0] == 0 }
        let op = Int.random(in: 0..<3, using: &rng)
        if op != 1, let c = clues.randomElement(using: &rng) { g[c] = 0 }
        if op != 0, let c = empty.randomElement(using: &rng) { g[c] = solution[c] }
        return g
    }

    /// Hill-climbs from a seed: accepts changes that don't lower the fitness, and now and then
    /// a worse one to get unstuck. Returns the best qualifying puzzle seen.
    static func climb<R: RandomNumberGenerator>(from seed: Grid, _ t: CampaignTarget, iterations: Int,
                                                deadline: Date, using rng: inout R) -> Mined? {
        guard let solution = BruteForce.solution(seed) else { return nil }
        var grid = seed
        var (fitness, best) = evaluate(seed, t)
        for _ in 0..<iterations where Date() < deadline {
            let next = mutate(grid, solution: solution, using: &rng)
            let (f, m) = evaluate(next, t)
            guard f >= fitness || Double.random(in: 0..<1, using: &rng) < 0.03 else { continue }
            grid = next
            fitness = f
            if let m, best.map({ m.score > $0.score }) ?? true { best = m }
        }
        return best
    }

    /// The bundled puzzle for a mined one, cut to a mid-solve start if the target wants that.
    static func bundle(_ m: Mined, _ t: CampaignTarget) -> CampaignPuzzle {
        var p = CampaignPuzzle(chapter: t.chapter.id, kind: t.kind, member: t.member, puzzle: m.puzzle,
                               uses: m.analysis.uses, outside: m.analysis.outside.sorted { $0.score < $1.score },
                               totalScore: m.analysis.totalScore)
        if t.startsMidSolve, let b = m.analysis.beforeFirstUse {
            p.values = b.grid
            p.candidates = b.candidates
            // What happens before the cut no longer counts.
            if let a = p.analysis() {
                p.outside = a.outside.sorted { $0.score < $1.score }
                p.totalScore = a.totalScore
            }
        }
        return p
    }
}
