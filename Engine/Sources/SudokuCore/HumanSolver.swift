/// Solves puzzles the way a person would.
///
/// Two orders are at work. Difficulty comes from levels (`Level`): the solver starts out knowing
/// only Beginner 1's techniques and moves up a level only when it is stuck, to the easiest level
/// that has a move, so a solve uses the smallest technique set that solves the puzzle. Within the
/// levels reached so far, it tries techniques in its own solve order (`allStrategies`), which puts
/// a move a player should look for early ahead of one that merely belongs to an easier level.
public struct HumanSolver: Sendable {
    /// The strategies in solve order.
    public let strategies: [any Strategy]

    /// Every strategy the engine knows, in solve order. Not the teaching order (`Technique.rank`):
    /// as in HoDoKu's default order, quads, basic fish, Remote Pair and BUG+1 come before the
    /// single-digit patterns and wings, and finned fish only after the wings and the uniqueness family, so a plain X-Wing is
    /// always found before a finned one. Levels still gate everything (see the type's comment).
    public static let allStrategies: [any Strategy] = [
        // Singles, then box/line intersections and subsets.
        FullHouse(), NakedSingle(), HiddenSingle(inBox: true), HiddenSingle(inBox: false),
        Pointing(), Claiming(), LockedSubset(size: 2), NakedSubset(size: 2), LockedSubset(size: 3),
        HiddenSubset(size: 2), NakedSubset(size: 3), HiddenSubset(size: 3),
        NakedSubset(size: 4), HiddenSubset(size: 4),
        // Basic fish, then Remote Pair and BUG+1 (cheap to spot, early in HoDoKu's order too).
        Fish(size: 2, kind: .basic), Fish(size: 3, kind: .basic), Fish(size: 4, kind: .basic),
        RemotePair(), BUGPlusOne(),
        // Single-digit patterns and wings.
        TurbotFamily(kind: .skyscraper), TurbotFamily(kind: .twoStringKite), TurbotFamily(kind: .turbotFish),
        EmptyRectangle(), XYWing(), XYZWing(), WWing(),
        // Uniqueness.
        UniqueRectangle(type: 1), UniqueRectangle(type: 2), UniqueRectangle(type: 5),
        UniqueRectangle(type: 4), UniqueRectangle(type: 6), UniqueRectangle(type: 3), UniqueRectangleMissing(),
        HiddenRectangle(), AvoidableRectangle(), AvoidableRectangle2(),
        // Finned fish.
        Fish(size: 2, kind: .finned), Fish(size: 2, kind: .sashimi),
        Fish(size: 3, kind: .finned), Fish(size: 3, kind: .sashimi),
        Fish(size: 4, kind: .finned), Fish(size: 4, kind: .sashimi),
        // Coloring, then chains.
        SimpleColoring(), SimpleColoring(wrap: true), MultiColoring(), WXYZWing(),
        ChainStrategy(mode: .x), ChainStrategy(mode: .xy), ChainStrategy(mode: .niceLoop), ChainStrategy(mode: .discontinuous),
        ChainStrategy(mode: .aic), ChainStrategy(mode: .grouped),
        // Almost locked sets and generalized fish.
        SueDeCoq(), ALSXZ(), ALSXYWing(), ALSChain(), DeathBlossom(), GeneralFish(kind: .franken),
        // Last resort.
        GeneralFish(kind: .mutant), KrakenFish(),
        ForcingChain(kind: .cell), ForcingChain(kind: .unit), ForcingChain(kind: .contradiction), ForcingNet(),
    ]

    public init(strategies: [any Strategy] = HumanSolver.allStrategies) {
        self.strategies = strategies
    }

    /// A solver restricted to a subset of techniques (e.g. a campaign chapter's).
    public init(allowing techniques: Set<Technique>) {
        strategies = HumanSolver.allStrategies.filter { techniques.contains($0.technique) }
    }

    /// The next move from `board` for a player who knows `level`'s techniques: the first step, in
    /// solve order, of a technique at or below `level` (a chain counts at its own `Step.level`).
    /// When there is none, the easiest level above with a move, up to `limit`, and the first step
    /// there in solve order (the step's `level` says which). Nil if nothing up to `limit` applies.
    ///
    /// The default level, Beginner 1, gives the easiest move in the position.
    public func nextStep(_ board: Board, level: Level = .beginner1, limit: Level = .extreme) -> Step? {
        let ceiling = min(level, limit)
        // Steps of ranked strategies (chains) too long for the ceiling, kept for escalating.
        var found: [Int: [Step]] = [:]
        for (i, s) in strategies.enumerated() where s.technique.level <= ceiling {
            var out = StepCollector(findAll: s.ranked)
            s.find(board, &out)
            if let best = Self.simplest(out.steps.filter { $0.level <= ceiling }) { return best }
            if !out.steps.isEmpty { found[i] = out.steps }
        }
        // Stuck at the ceiling: move up one level at a time.
        var next = ceiling.next
        while let l = next, l <= limit {
            for (i, s) in strategies.enumerated() where s.technique.level <= l {
                if s.technique.level == l {
                    var out = StepCollector(findAll: s.ranked)
                    s.find(board, &out)
                    if !out.steps.isEmpty { found[i] = out.steps }
                }
                if let steps = found[i], let best = Self.simplest(steps.filter { $0.level <= l }) { return best }
            }
            next = l.next
        }
        return nil
    }

    /// Every instance of one technique in the position (for training drills).
    public func allSteps(_ board: Board, technique: Technique) -> [Step] {
        var out = StepCollector(findAll: true, exhaustive: true)
        for s in strategies where s.technique == technique { s.find(board, &out) }
        return out.steps
    }

    /// Every technique that currently has at least one application, in solve order.
    public func availableTechniques(_ board: Board) -> [Technique] {
        strategies.compactMap { s in
            var out = StepCollector(findAll: false)
            s.find(board, &out)
            return out.steps.isEmpty ? nil : s.technique
        }
    }

    /// The hardest technique the solver needs before it can place another digit: it solves on from
    /// `board` and stops at the first step with a placement. This is what a player had to see to make
    /// progress, so it's how player skill is attributed to techniques. `.bruteForce` when the known
    /// techniques get stuck first; nil when the board is already solved.
    public func nextPlacementBottleneck(_ board: Board, maxSteps: Int = 500) -> Technique? {
        guard !board.isSolved else { return nil }
        var b = board
        var hardest: Technique?
        var ceiling = Level.beginner1
        for _ in 0..<maxSteps {
            guard let s = nextStep(b, level: ceiling) else { return .bruteForce }
            ceiling = max(ceiling, s.level)
            if hardest.map({ s.technique > $0 }) ?? true { hardest = s.technique }
            if !s.placements.isEmpty { return hardest }
            b.apply(s)
        }
        return .bruteForce
    }

    static func simplest(_ steps: [Step]) -> Step? {
        steps.min { a, b in
            if a.complexity != b.complexity { return a.complexity < b.complexity }
            return (a.eliminations.count + a.placements.count) > (b.eliminations.count + b.placements.count)
        }
    }

    /// Solves from the given position, recording every step. The solver starts at `level` and
    /// moves up only when stuck (see `nextStep`), never past `limit`. If `solution` is supplied and
    /// the solver gets stuck, it falls back to revealing a cell (recorded as `.bruteForce`).
    /// `stop` sees each step as it's taken and can end the solve early by returning true.
    public func solve(_ start: Board, solution: Grid? = nil, from level: Level = .beginner1, limit: Level = .extreme,
                      maxSteps: Int = 2000, stop: (Step) -> Bool = { _ in false }) -> SolveLog {
        var board = start
        var steps: [Step] = []
        var ceiling = level
        while !board.isSolved && steps.count < maxSteps {
            if let step = nextStep(board, level: ceiling, limit: limit) {
                ceiling = max(ceiling, step.level)
                board.apply(step)
                steps.append(step)
                if stop(step) { break }
            } else if let sol = solution {
                // Reveal the empty cell with the fewest candidates.
                let c = board.emptyCells.min { board.candidates[$0].nonzeroBitCount < board.candidates[$1].nonzeroBitCount }!
                let step = Step(.bruteForce, placements: [Candidate(c, sol[c])], houses: Geometry.housesOfCell[c],
                                highlights: [Highlight(c, sol[c], .pattern)],
                                explanation: "No known technique applies here. \(Geometry.cellName(c)) is \(sol[c]).")
                board.apply(step)
                steps.append(step)
            } else {
                break
            }
        }
        return SolveLog(steps: steps, final: board)
    }

    public func solve(_ grid: Grid) -> SolveLog {
        solve(Board(grid), solution: BruteForce.solution(grid))
    }
}

public struct SolveLog: Sendable {
    public var steps: [Step]
    public var final: Board
    public var solved: Bool { final.isSolved }
}
