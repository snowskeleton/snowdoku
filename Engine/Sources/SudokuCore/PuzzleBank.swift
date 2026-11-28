/// A puzzle mined offline and bundled with the app, stored with its rating so the app never has
/// to re-rate it (rating an Extreme puzzle takes seconds).
///
/// The bank is a text file with one puzzle per line, tab-separated:
///
///     <81-char givens>  <hardest>  <total score>  <step count>  <technique:count,technique:count,…>  [<hardest step's tier>]
///
/// Techniques are raw names, easiest first. The tier follows from the hardest move and the total
/// score, so it isn't stored. The hardest move is the hardest technique, unless a long chain counts
/// as harder (`Rating.hardestStep`); only then is there a sixth field, that tier's raw value.
public struct BankedPuzzle: Hashable, Sendable {
    public var puzzle: Grid
    public var rating: Rating

    public init(puzzle: Grid, rating: Rating) {
        self.puzzle = puzzle
        self.rating = rating
    }

    public var difficulty: Difficulty { rating.difficulty }

    public init?(line: Substring) {
        let f = line.split(separator: "\t", omittingEmptySubsequences: false)
        guard f.count == 5 || f.count == 6, let g = Grid(String(f[0])), let hardest = Technique(rawValue: String(f[1])),
              let total = Int(f[2]), let steps = Int(f[3]) else { return nil }
        var counts: [Technique: Int] = [:]
        for pair in f[4].split(separator: ",") {
            let kv = pair.split(separator: ":")
            guard kv.count == 2, let t = Technique(rawValue: String(kv[0])), let n = Int(kv[1]) else { return nil }
            counts[t] = n
        }
        var hardestStep: Difficulty?
        if f.count == 6 {
            guard let raw = Int(f[5]), let d = Difficulty(rawValue: raw) else { return nil }
            hardestStep = d
        }
        self.init(puzzle: g, rating: Rating(hardest: hardest, hardestStep: hardestStep, totalScore: total, counts: counts, stepCount: steps))
    }

    public var line: String {
        let counts = rating.techniques.map { "\($0.rawValue):\(rating.counts[$0]!)" }.joined(separator: ",")
        let line = "\(puzzle.string)\t\(rating.hardest.rawValue)\t\(rating.totalScore)\t\(rating.stepCount)\t\(counts)"
        return rating.hardestStep.map { line + "\t\($0.rawValue)" } ?? line
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
    /// How many of each tier's puzzles (the first ones, in bank order) dailies draw from. Pinned, so
    /// appending puzzles to the bank never changes a daily. Raising a count changes every daily of
    /// that tier from then on, and players on different app versions would get different puzzles.
    public static let poolSize: [Difficulty: Int] = [
        .beginner: 500, .easy: 499, .medium: 538, .hard: 466, .expert: 491, .master: 506, .extreme: 150,
    ]

    /// Today's pick from a whole tier of the bank, drawing only from its first `poolSize` puzzles.
    public static func pick(from tier: [BankedPuzzle], difficulty: Difficulty, seed: UInt64) -> GeneratedPuzzle? {
        pick(from: Array(tier.prefix(poolSize[difficulty] ?? tier.count)), seed: seed)
    }

    /// Today's pick from a tier of the bank: the same puzzle and transform for everyone on `seed`'s
    /// day, and unaffected by engine changes as long as the bank's lines keep their order.
    public static func pick(from pool: [BankedPuzzle], seed: UInt64) -> GeneratedPuzzle? {
        guard !pool.isEmpty else { return nil }
        var rng = SplitMix64(seed: seed)
        let index = Int(rng.next() % UInt64(pool.count))
        return pool[index].generated(.random(using: &rng))
    }
}
