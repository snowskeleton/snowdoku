/// A puzzle mined offline and bundled with the app, stored with its rating so the app never has
/// to re-rate it (rating an Extreme puzzle takes seconds).
///
/// The bank is a text file with one puzzle per line, tab-separated:
///
///     <81-char givens>  <hardest>  <total score>  <step count>  <technique:count,technique:count,…>  <technique level>
///
/// Techniques are raw names, easiest first. The technique level (`Rating.techniqueLevel`, a raw
/// `Level` name) is stored because a long chain can raise it above the hardest technique's level;
/// the puzzle's level and tier follow from it and the total score.
public struct BankedPuzzle: Hashable, Sendable {
    public var puzzle: Grid
    public var rating: Rating

    public init(puzzle: Grid, rating: Rating) {
        self.puzzle = puzzle
        self.rating = rating
    }

    public var difficulty: Difficulty { rating.difficulty }
    public var level: Level { rating.level }

    public init?(line: Substring) {
        let f = line.split(separator: "\t", omittingEmptySubsequences: false)
        guard f.count == 6, let g = Grid(String(f[0])), let hardest = Technique(rawValue: String(f[1])),
              let total = Int(f[2]), let steps = Int(f[3]), let level = Level(rawValue: String(f[5])) else { return nil }
        var counts: [Technique: Int] = [:]
        for pair in f[4].split(separator: ",") {
            let kv = pair.split(separator: ":")
            guard kv.count == 2, let t = Technique(rawValue: String(kv[0])), let n = Int(kv[1]) else { return nil }
            counts[t] = n
        }
        self.init(puzzle: g, rating: Rating(hardest: hardest, techniqueLevel: level, totalScore: total, counts: counts, stepCount: steps))
    }

    public var line: String {
        let counts = rating.techniques.map { "\($0.rawValue):\(rating.counts[$0]!)" }.joined(separator: ",")
        return "\(puzzle.string)\t\(rating.hardest.rawValue)\t\(rating.totalScore)\t\(rating.stepCount)\t\(counts)\t\(rating.techniqueLevel.rawValue)"
    }

    /// The puzzle, relabeled and reshuffled by `transform`, with its solution. Nil if it isn't unique.
    public func generated(_ transform: GridTransform = .identity) -> GeneratedPuzzle? {
        let p = transform.apply(puzzle)
        guard let s = BruteForce.solution(p) else { return nil }
        return GeneratedPuzzle(puzzle: p, solution: s, rating: rating)
    }

    /// Parses a whole bank file, skipping blank and malformed lines.
    public static func parse(_ text: String) -> [BankedPuzzle] {
        text.split(separator: "\n").compactMap { BankedPuzzle(line: $0) }
    }
}

extension Daily {
    /// How many puzzles (the first ones, in bank order) of each level dailies draw from. Pinned,
    /// so appending puzzles to the bank never changes a daily. Raising a count changes every
    /// daily that lands on that level from then on, and players on different app versions would
    /// get different puzzles.
    public static let poolSize: [Level: Int] = [
        .beginner1: 250, .beginner2: 481,
        .easy1: 323, .easy2: 250, .easy3: 250,
        .medium1: 359, .medium2: 250, .medium3: 250, .medium4: 250,
        .hard1: 328, .hard2: 252, .hard3: 249, .hard4: 250,
        .expert1: 248, .expert2: 250, .expert3: 367, .expert4: 251,
        .master1: 477, .master2: 250, .master3: 250,
    ]

    /// Today's pick from a whole tier of the bank (its puzzles in bank order, any mix of levels):
    /// a level of the tier, each equally likely, then a puzzle among the first `poolSize` of
    /// that level. Levels with no puzzles are skipped.
    public static func pick(from tier: [BankedPuzzle], difficulty: Difficulty, seed: UInt64) -> GeneratedPuzzle? {
        let pools = Level.levels(in: difficulty).map { l in
            let all = tier.filter { $0.level == l }
            return Array(all.prefix(poolSize[l] ?? all.count))
        }.filter { !$0.isEmpty }
        guard !pools.isEmpty else { return nil }
        var rng = SplitMix64(seed: seed)
        let pool = pools[Int(rng.next() % UInt64(pools.count))]
        return pick(from: pool, using: &rng)
    }

    /// Today's pick from a pool of the bank: the same puzzle and transform for everyone on `seed`'s
    /// day, and unaffected by engine changes as long as the bank's lines keep their order.
    public static func pick(from pool: [BankedPuzzle], seed: UInt64) -> GeneratedPuzzle? {
        var rng = SplitMix64(seed: seed)
        return pick(from: pool, using: &rng)
    }

    static func pick(from pool: [BankedPuzzle], using rng: inout SplitMix64) -> GeneratedPuzzle? {
        guard !pool.isEmpty else { return nil }
        let index = Int(rng.next() % UInt64(pool.count))
        return pool[index].generated(.random(using: &rng))
    }
}
