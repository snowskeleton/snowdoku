/// Difficulty rating of a puzzle derived from a full human-style solve.
public struct Rating: Hashable, Sendable, Codable {
    /// Hardest technique used (by teaching order, `Technique.rank`).
    public var hardest: Technique
    /// The smallest level whose techniques solve the puzzle: the highest `Step.level` in the
    /// solver's solve, which only moves up a level when stuck. Usually `hardest`'s level; higher
    /// when a long chain counts as a harder move.
    public var techniqueLevel: Level
    /// Sum of scores of every step (a finer-grained "how long/tedious" measure).
    public var totalScore: Int
    /// How many times each technique was used.
    public var counts: [Technique: Int]
    public var stepCount: Int

    public init(hardest: Technique, techniqueLevel: Level, totalScore: Int, counts: [Technique: Int], stepCount: Int) {
        self.hardest = hardest
        self.techniqueLevel = techniqueLevel
        self.totalScore = totalScore
        self.counts = counts
        self.stepCount = stepCount
    }

    /// Whether the total score is over the technique level's tier's `maxScore` (a long, grinding
    /// solve), which moves the puzzle up one tier. The same idea as HoDoKu's rating.
    public var isBumped: Bool {
        guard let max = techniqueLevel.tier.maxScore else { return false }
        return totalScore > max
    }
    /// The puzzle's level: its technique level, or the next tier's first level when the solve is
    /// bumped (it needs nothing new there, but plays like that tier).
    public var level: Level {
        guard isBumped, let up = Difficulty(rawValue: techniqueLevel.tier.rawValue + 1) else { return techniqueLevel }
        return Level.first(in: up)
    }
    /// The puzzle's tier: its level's tier.
    public var difficulty: Difficulty { level.tier }

    /// True if no brute-force step was needed.
    public var solvedLogically: Bool { counts[.bruteForce] == nil }

    /// Techniques used, easiest first.
    public var techniques: [Technique] { counts.keys.sorted() }
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

    /// Rates a puzzle only if it lands in `tier`, and gives up as soon as the solve shows it can't.
    /// Gives the same answer as rating it fully and comparing, but skips the hardest part of the
    /// work on puzzles that overshoot, which is most of them when generating for a tier.
    public static func rate(_ puzzle: Grid, solution: Grid, ifIn tier: Difficulty) -> Rating? {
        rate(puzzle, solution: solution) { $0.difficulty == tier }
    }

    /// Rates a puzzle only if its level (`Rating.level`, after any bump) is `level`, giving up as
    /// soon as the solve shows it can't.
    public static func rate(_ puzzle: Grid, solution: Grid, ifIn level: Level) -> Rating? {
        rate(puzzle, solution: solution) { $0.level == level }
    }

    /// The shared fast path: `accept` must hold for the final rating. A rating's final level never
    /// goes below the level the solve has reached, and the total only grows, so the solve stops as
    /// soon as its level is past the highest level `accept` takes, or the total bumps that level's
    /// tier. Ratings of Extreme are always done in full.
    private static func rate(_ puzzle: Grid, solution: Grid, accept: (Rating) -> Bool) -> Rating? {
        // The highest technique level that can still give an accepted rating, found by asking
        // about unbumped ratings of each level. Bumped ratings land on a higher level, so this caps
        // what the solve may reach.
        let probe = { (l: Level) in Rating(hardest: .fullHouse, techniqueLevel: l, totalScore: 0, counts: [:], stepCount: 0) }
        guard let top = Level.allCases.last(where: { accept(probe($0)) }), top != .extreme else {
            let r = rate(puzzle, solution: solution)
            return accept(r) ? r : nil
        }
        var total = 0
        var reached = Level.beginner1
        let log = HumanSolver().solve(Board(puzzle), limit: top) { step in
            total += step.score
            reached = max(reached, step.level)
            return reached > top || (reached.tier == top.tier && top.tier.maxScore.map { total > $0 } == true)
        }
        guard log.solved else { return nil }
        let r = rating(from: log.steps)
        return accept(r) ? r : nil
    }

    public static func rating(from steps: [Step]) -> Rating {
        var counts: [Technique: Int] = [:]
        var total = 0
        var hardest = Technique.fullHouse
        var level = Level.beginner1
        for s in steps {
            counts[s.technique, default: 0] += 1
            total += s.score
            hardest = max(hardest, s.technique)
            level = max(level, s.level)
        }
        return Rating(hardest: hardest, techniqueLevel: level, totalScore: total, counts: counts, stepCount: steps.count)
    }
}
