/// Solves puzzles the way a person would: always applying the easiest technique available.
public struct HumanSolver: Sendable {
    public let strategies: [any Strategy]

    /// Every strategy the engine knows, ordered from easiest to hardest.
    public static let allStrategies: [any Strategy] = {
        let list: [any Strategy] = [
            FullHouse(), HiddenSingle(inBox: true), HiddenSingle(inBox: false), NakedSingle(),
            Pointing(), Claiming(), LockedSubset(size: 2), LockedSubset(size: 3),
            NakedSubset(size: 2), HiddenSubset(size: 2), NakedSubset(size: 3), HiddenSubset(size: 3),
            NakedSubset(size: 4), HiddenSubset(size: 4),
            Fish(size: 2, kind: .basic), Fish(size: 3, kind: .basic), Fish(size: 4, kind: .basic),
            Fish(size: 2, kind: .finned), Fish(size: 2, kind: .sashimi),
            Fish(size: 3, kind: .finned), Fish(size: 3, kind: .sashimi),
            Fish(size: 4, kind: .finned), Fish(size: 4, kind: .sashimi),
            TurbotFamily(kind: .skyscraper), TurbotFamily(kind: .twoStringKite), TurbotFamily(kind: .turbotFish),
            EmptyRectangle(),
            XYWing(), XYZWing(), WWing(), WXYZWing(),
            UniqueRectangle(type: 1), UniqueRectangle(type: 2), UniqueRectangle(type: 3), UniqueRectangle(type: 4),
            UniqueRectangle(type: 5), UniqueRectangle(type: 6), AvoidableRectangle(), AvoidableRectangle2(),
            HiddenRectangle(), BUGPlusOne(),
            SimpleColoring(), SimpleColoring(wrap: true), MultiColoring(),
            ChainStrategy(mode: .remotePair), ChainStrategy(mode: .x), ChainStrategy(mode: .xy), ChainStrategy(mode: .niceLoop), ChainStrategy(mode: .discontinuous),
            ChainStrategy(mode: .aic), ChainStrategy(mode: .grouped),
            SueDeCoq(), ALSXZ(), ALSXYWing(), ALSChain(), DeathBlossom(),
            GeneralFish(kind: .franken), GeneralFish(kind: .mutant), KrakenFish(),
            ForcingChain(kind: .cell), ForcingChain(kind: .unit), ForcingChain(kind: .contradiction), ForcingNet(),
        ]
        // Stable sort by score so the list order is the teaching order.
        return list.enumerated().sorted {
            ($0.element.technique.score, $0.offset) < ($1.element.technique.score, $1.offset)
        }.map(\.element)
    }()

    public init(strategies: [any Strategy] = HumanSolver.allStrategies) {
        self.strategies = strategies
    }

    /// A solver restricted to a subset of techniques (e.g. "what can a medium player do?").
    public init(allowing techniques: Set<Technique>) {
        strategies = HumanSolver.allStrategies.filter { techniques.contains($0.technique) }
    }

    /// The easiest available deduction, or nil if no known technique applies.
    public func nextStep(_ board: Board) -> Step? {
        for s in strategies {
            var out = StepCollector(findAll: s.ranked)
            s.find(board, &out)
            if let best = Self.simplest(out.steps) { return best }
        }
        return nil
    }

    /// Every instance of one technique in the position (for training drills).
    public func allSteps(_ board: Board, technique: Technique) -> [Step] {
        var out = StepCollector(findAll: true)
        for s in strategies where s.technique == technique { s.find(board, &out) }
        return out.steps
    }

    /// Every technique that currently has at least one application, easiest first.
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
        for _ in 0..<maxSteps {
            guard let s = nextStep(b) else { return .bruteForce }
            if hardest.map({ s.technique.score > $0.score }) ?? true { hardest = s.technique }
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

    /// Solves from the given position, recording every step. If `solution` is supplied and the
    /// solver gets stuck, it falls back to revealing a cell (recorded as `.bruteForce`).
    public func solve(_ start: Board, solution: Grid? = nil, maxSteps: Int = 2000) -> SolveLog {
        var board = start
        var steps: [Step] = []
        while !board.isSolved && steps.count < maxSteps {
            if let step = nextStep(board) {
                board.apply(step)
                steps.append(step)
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
