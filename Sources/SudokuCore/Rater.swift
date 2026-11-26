/// Difficulty rating of a puzzle derived from a full human-style solve.
public struct Rating: Hashable, Sendable, Codable {
    /// Hardest technique required.
    public var hardest: Technique
    /// Tier of the hardest technique.
    public var difficulty: Difficulty { hardest.difficulty }
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

    public static func rating(from steps: [Step]) -> Rating {
        var counts: [Technique: Int] = [:]
        var total = 0
        var hardest = Technique.fullHouse
        for s in steps {
            counts[s.technique, default: 0] += 1
            total += s.technique.score
            if s.technique.score > hardest.score { hardest = s.technique }
        }
        return Rating(hardest: hardest, totalScore: total, counts: counts, stepCount: steps.count)
    }
}
