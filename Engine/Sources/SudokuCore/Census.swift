/// How often each technique comes up along the solver's own path, to tell a technique that is
/// genuinely rare from one an easier technique always covers, or one the solving order starves.
///
/// Only "stuck" positions count: ones where the solver's next step is neither a single nor a
/// forcing chain (forcing steps are too slow to probe at every position). At each, for every
/// probed technique:
/// - `available`: it has at least one instance.
/// - `novel`: one of its instances removes a candidate (or places a digit) that no easier
///   available technique does at that position. A technique that is available but never novel is
///   fully covered by easier ones; raising its priority couldn't make it show up more.
/// - `chosen`: it is the solver's next step.
/// - `puzzles`: puzzles with at least one position where it is available.
public struct Census: Sendable {
    public struct Counts: Sendable {
        public var available = 0, novel = 0, chosen = 0, puzzles = 0
        public init() {}
    }

    public var puzzles = 0
    public var stuckPositions = 0
    public var counts: [Technique: Counts] = [:]

    public init() {}

    static let singles: Set<Technique> = [.fullHouse, .nakedSingle, .hiddenSingleBox, .hiddenSingleLine]

    /// The techniques a census probes: everything but the singles, forcing chains and nets, and
    /// trial and error, easiest first.
    public static let probed: [Technique] = Technique.allCases
        .filter { $0 < .cellForcingChain && !singles.contains($0) }
        .sorted()

    /// The positions along the solver's path through `puzzle` whose next step is neither a single
    /// nor a forcing chain, with that step.
    public static func stuckPositions(of puzzle: Grid, solver: HumanSolver = HumanSolver()) -> [(board: Board, next: Step)] {
        var out: [(Board, Step)] = []
        var board = Board(puzzle)
        var level = Level.beginner1
        for _ in 0..<1000 {
            guard !board.isSolved, let step = solver.nextStep(board, level: level) else { break }
            level = max(level, step.level)
            if !singles.contains(step.technique) && step.technique < .cellForcingChain {
                out.append((board, step))
            }
            board.apply(step)
        }
        return out
    }

    /// Everything one technique removes or places in a position, over all its instances.
    public static func findings(_ board: Board, _ technique: Technique, probe: HumanSolver) -> Set<Candidate> {
        var all = Set<Candidate>()
        for s in probe.allSteps(board, technique: technique) {
            all.formUnion(s.eliminations)
            all.formUnion(s.placements)
        }
        return all
    }

    /// The census of one puzzle.
    public static func of(_ puzzle: Grid, solver: HumanSolver = HumanSolver(),
                          probe: HumanSolver = HumanSolver(allowing: Set(probed))) -> Census {
        var census = Census()
        census.puzzles = 1
        var seen = Set<Technique>()
        for (board, next) in stuckPositions(of: puzzle, solver: solver) {
            census.stuckPositions += 1
            census.counts[next.technique, default: Counts()].chosen += 1
            var covered = Set<Candidate>()
            for t in probe.availableTechniques(board).sorted() {   // easiest first
                census.counts[t, default: Counts()].available += 1
                seen.insert(t)
                let mine = findings(board, t, probe: probe)
                if !mine.isSubset(of: covered) { census.counts[t, default: Counts()].novel += 1 }
                covered.formUnion(mine)
            }
        }
        for t in seen { census.counts[t, default: Counts()].puzzles += 1 }
        return census
    }

    public mutating func add(_ other: Census) {
        puzzles += other.puzzles
        stuckPositions += other.stuckPositions
        for (t, c) in other.counts {
            counts[t, default: Counts()].available += c.available
            counts[t, default: Counts()].novel += c.novel
            counts[t, default: Counts()].chosen += c.chosen
            counts[t, default: Counts()].puzzles += c.puzzles
        }
    }
}
