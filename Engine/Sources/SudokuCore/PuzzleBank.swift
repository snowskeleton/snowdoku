/// A puzzle mined offline and bundled with the app, stored with its rating so the app never has
/// to re-rate it (rating an Extreme puzzle takes seconds).
///
/// The bank is a text file with one puzzle per line, tab-separated:
///
///     <81-char givens>  <hardest>  <total score>  <step count>  <technique:count,technique:count,…>
///
/// Techniques are raw names, easiest first. The tier follows from the hardest technique and the total score, so it isn't stored.
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
        guard f.count == 5, let g = Grid(String(f[0])), let hardest = Technique(rawValue: String(f[1])),
              let total = Int(f[2]), let steps = Int(f[3]) else { return nil }
        var counts: [Technique: Int] = [:]
        for pair in f[4].split(separator: ",") {
            let kv = pair.split(separator: ":")
            guard kv.count == 2, let t = Technique(rawValue: String(kv[0])), let n = Int(kv[1]) else { return nil }
            counts[t] = n
        }
        self.init(puzzle: g, rating: Rating(hardest: hardest, totalScore: total, counts: counts, stepCount: steps))
    }

    public var line: String {
        let counts = rating.techniques.map { "\($0.rawValue):\(rating.counts[$0]!)" }.joined(separator: ",")
        return "\(puzzle.string)\t\(rating.hardest.rawValue)\t\(rating.totalScore)\t\(rating.stepCount)\t\(counts)"
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
    /// Today's pick from a tier of the bank: the same puzzle and transform for everyone on `seed`'s
    /// day, and unaffected by engine changes as long as the bank's lines keep their order.
    public static func pick(from pool: [BankedPuzzle], seed: UInt64) -> GeneratedPuzzle? {
        guard !pool.isEmpty else { return nil }
        var rng = SplitMix64(seed: seed)
        let index = Int(rng.next() % UInt64(pool.count))
        return pool[index].generated(.random(using: &rng))
    }
}
