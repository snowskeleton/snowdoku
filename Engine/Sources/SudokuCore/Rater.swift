/// Difficulty rating of a puzzle derived from a full human-style solve.
public struct Rating: Hashable, Sendable, Codable {
    /// Hardest technique required.
    public var hardest: Technique
    /// The tier of the hardest step, when that's above the hardest technique's tier: a long chain
    /// counts as a harder move (`Step.difficulty`). Nil otherwise.
    public var hardestStep: Difficulty?
    /// The tier of the hardest move: the hardest technique's tier, or a long chain's.
    public var baseDifficulty: Difficulty { max(hardest.difficulty, hardestStep ?? .beginner) }
    /// The puzzle's tier: the hardest move's tier, or one tier higher when the total score
    /// is over that tier's `maxScore` (a long, grinding solve). The same idea as HoDoKu's rating.
    public var difficulty: Difficulty {
        let base = baseDifficulty
        guard let max = base.maxScore, totalScore > max else { return base }
        return Difficulty(rawValue: base.rawValue + 1) ?? base
    }
    /// Sum of scores of every step (a finer-grained "how long/tedious" measure).
    public var totalScore: Int
    /// How many times each technique was used.
    public var counts: [Technique: Int]
    public var stepCount: Int
    /// True if no brute-force step was needed.
    public var solvedLogically: Bool { counts[.bruteForce] == nil }

    /// Techniques used, easiest first.
    public var techniques: [Technique] { counts.keys.sorted { $0.score < $1.score } }
    /// Techniques used that are above the singles level (what a level "requires").
    public var advancedTechniques: [Technique] { techniques.filter { $0.difficulty > .beginner } }
}

public enum Rater {
    /// Rates a puzzle. Returns nil when it doesn't have exactly one solution.
    public static func rate(_ puzzle: Grid, solver: HumanSolver = HumanSolver()) -> Rating? {
        guard case .unique(let solution) = BruteForce.analyze(puzzle) else { return nil }
        return rate(puzzle, solution: solution, solver: solver)
    }

    public static func rate(_ puzzle: Grid, solution: Grid, solver: HumanSolver = HumanSolver()) -> Rating {
        let log = solver.solve(Board(puzzle), solution: solution)
        return rating(from: log.steps)
    }

    /// Rates a puzzle only if it lands in `tier`, and gives up as soon as the solve shows it can't:
    /// when it needs a technique above the tier, or its score already bumps it past the tier. Gives
    /// the same answer as rating it fully and comparing, but skips the hardest part of the work on
    /// puzzles that overshoot, which is most of them when generating for a tier.
    public static func rate(_ puzzle: Grid, solution: Grid, ifIn tier: Difficulty) -> Rating? {
        guard tier != .extreme else {
            let r = rate(puzzle, solution: solution)
            return r.difficulty == tier ? r : nil
        }
        var total = 0
        var hardest = Difficulty.beginner
        let log = HumanSolver.upTo(tier).solve(Board(puzzle)) { step in
            total += step.score
            hardest = max(hardest, step.difficulty)
            // The hardest move only gets harder and the total only grows. (A long chain can be
            // harder than the tier even though its technique isn't.)
            return hardest > tier || (hardest == tier && tier.maxScore.map { total > $0 } == true)
        }
        guard log.solved else { return nil }
        let r = rating(from: log.steps)
        return r.difficulty == tier ? r : nil
    }

    public static func rating(from steps: [Step]) -> Rating {
        var counts: [Technique: Int] = [:]
        var total = 0
        var hardest = Technique.fullHouse
        var hardestStep = Difficulty.beginner
        for s in steps {
            counts[s.technique, default: 0] += 1
            total += s.score
            if s.technique.score > hardest.score { hardest = s.technique }
            hardestStep = max(hardestStep, s.difficulty)
        }
        return Rating(hardest: hardest, hardestStep: hardestStep > hardest.difficulty ? hardestStep : nil,
                      totalScore: total, counts: counts, stepCount: steps.count)
    }
}
