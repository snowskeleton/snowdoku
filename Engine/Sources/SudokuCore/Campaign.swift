/// The campaign: a guided path of chapters, each teaching one technique or a small family of them.
///
/// Every chapter has puzzles of several kinds (`CampaignKind`), mined offline with
/// `sudokugen campaign` so that the chapter's technique is the focus. How strongly it is the focus
/// is measured in **uses**: placements whose bottleneck (the hardest technique needed to place the
/// next digit) belongs to the chapter's family. That is the same measure the app records per
/// correct digit, so the in-game counter agrees with the miner.
public struct CampaignChapter: Hashable, Sendable, Identifiable {
    public var id: String
    public var title: String
    /// 1-based part (`CampaignChapter.parts`).
    public var part: Int
    /// The techniques taught, lead technique first. A use of any of them counts.
    public var family: [Technique]

    public init(_ id: String, _ title: String, part: Int, _ family: [Technique]) {
        self.id = id
        self.title = title
        self.part = part
        self.family = family
    }

    public var lead: Technique { family[0] }
    public var familySet: Set<Technique> { Set(family) }
    public var index: Int { Self.all.firstIndex { $0.id == id }! }

    public static let parts = ["Singles", "Notes", "Patterns", "Wings & Fish", "Chains", "Master", "Extreme"]

    /// The core path, in teaching order.
    public static let all: [CampaignChapter] = [
        .init("fullHouse", "Full House", part: 1, [.fullHouse]),
        .init("hiddenSingleBox", "Hidden Single in a Box", part: 1, [.hiddenSingleBox]),
        .init("nakedSingle", "Naked Single", part: 1, [.nakedSingle]),
        .init("hiddenSingleLine", "Hidden Single in a Line", part: 1, [.hiddenSingleLine]),

        .init("pointing", "Pointing", part: 2, [.pointing]),
        .init("claiming", "Claiming", part: 2, [.claiming]),
        .init("nakedPair", "Naked Pairs", part: 2, [.nakedPair, .lockedPair]),
        .init("hiddenPair", "Hidden Pairs", part: 2, [.hiddenPair]),
        .init("triples", "Triples", part: 2, [.nakedTriple, .hiddenTriple, .lockedTriple]),

        .init("xWing", "X-Wing", part: 3, [.xWing]),
        .init("skyscraper", "Skyscraper", part: 3, [.skyscraper]),
        .init("twoStringKite", "2-String Kite", part: 3, [.twoStringKite]),
        .init("turbotFish", "Turbot Fish", part: 3, [.turbotFish]),
        .init("finnedXWing", "Finned X-Wing", part: 3, [.finnedXWing, .sashimiXWing]),
        .init("remotePair", "Remote Pair", part: 3, [.remotePair]),
        .init("uniqueness", "Unique Rectangles", part: 3,
              [.uniqueRectangle1, .uniqueRectangle2, .uniqueRectangle4, .hiddenRectangle, .bugPlusOne]),

        .init("xyWing", "XY-Wing", part: 4, [.xyWing]),
        .init("xyzWing", "XYZ-Wing", part: 4, [.xyzWing]),
        .init("wWing", "W-Wing", part: 4, [.wWing]),
        .init("emptyRectangle", "Empty Rectangle", part: 4, [.emptyRectangle]),
        .init("swordfish", "Swordfish", part: 4, [.swordfish, .jellyfish]),

        .init("xChain", "X-Chain", part: 5, [.xChain]),
        .init("xyChain", "XY-Chain", part: 5, [.xyChain]),
        .init("wxyzWing", "WXYZ-Wing", part: 5, [.wxyzWing]),
        .init("finnedSwordfish", "Finned Swordfish", part: 5,
              [.finnedSwordfish, .sashimiSwordfish, .finnedJellyfish, .sashimiJellyfish]),
        .init("aic", "Nice Loops & AIC", part: 5, [.niceLoop, .discontinuousNiceLoop, .aic, .groupedAIC]),

        .init("als", "Almost Locked Sets", part: 6, [.alsXZ, .alsXYWing, .alsChain]),

        .init("forcingChain", "Forcing Chains", part: 7, [.cellForcingChain, .unitForcingChain, .forcingContradiction]),
        .init("forcingNet", "Forcing Nets", part: 7, [.forcingNet]),
    ]

    public static func named(_ id: String) -> CampaignChapter? { all.first { $0.id == id } }

    static let singles: Set<Technique> = [.fullHouse, .hiddenSingleBox, .hiddenSingleLine, .nakedSingle]

    /// What a spotlight puzzle may need besides its technique: just enough to place digits.
    public var placementBasics: Set<Technique> { part == 1 ? [.fullHouse] : Self.singles }

    /// Everything taught up to and including this chapter.
    public var cumulative: Set<Technique> {
        var s = part == 1 ? Set<Technique>() : Self.singles
        for c in Self.all[...index] { s.formUnion(c.family) }
        return s
    }

    /// The techniques a puzzle of this kind may need. `member` picks the family member a spotlight
    /// puzzle is dedicated to.
    public func allowed(_ kind: CampaignKind, member: Technique? = nil) -> Set<Technique> {
        switch kind {
        case .spotlight: placementBasics.union([member ?? lead])
        default: cumulative
        }
    }

    /// Techniques too basic to count as "something else" in a puzzle: Full House in the singles
    /// part, every single after it.
    public var routine: Set<Technique> { part == 1 ? [.fullHouse] : Self.singles }

    /// Earlier techniques that can make a puzzle more varied (taught, not routine, not the family).
    public var earlier: Set<Technique> { cumulative.subtracting(routine).subtracting(family) }

    /// How many different earlier techniques a mixed puzzle must need.
    public var mixedVariety: Int { min(2, earlier.count) }

    /// The kinds this chapter has. Mixed needs earlier techniques to mix in; a chapter with
    /// nothing earlier at all (Full House) has no practice either, which would be its spotlight again.
    public var kinds: [CampaignKind] {
        if cumulative.count == 1 { return [.spotlight, .boss, .endless] }
        return mixedVariety > 0 ? [.spotlight, .context, .mixed, .boss, .endless] : [.spotlight, .context, .boss, .endless]
    }

    /// Whether this chapter's puzzles of a kind keep to `CampaignKind.maxClues`. Puzzles solved
    /// by Full House alone need far more clues, so the first chapter is exempt.
    public func capsClues(_ kind: CampaignKind) -> Bool { kind.capsClues && cumulative.count > 1 }

    /// The family members a puzzle of this kind is about: one member for a spotlight, else all.
    public func focusTechniques(_ kind: CampaignKind, member: Technique? = nil) -> Set<Technique> {
        kind == .spotlight ? [member ?? lead] : familySet
    }
}

/// The kinds of puzzle in a chapter, in the order they're played.
public enum CampaignKind: String, Codable, CaseIterable, Sendable {
    /// Dedicated to one family member, needing as little else as possible; often starts mid-solve.
    case spotlight
    /// From the givens, may need anything taught so far, preferring little else.
    case context
    /// Needs at least two earlier non-single techniques besides the family.
    case mixed
    /// The chapter's hardest: most uses and most variety.
    case boss
    /// Random practice after the boss.
    case endless

    /// Puzzles starting from their givens have at most this many, like real puzzles (the bank's
    /// most is 29, median 24). Spotlights may be contrived and are exempt.
    public static let maxClues = 28

    public var capsClues: Bool { self != .spotlight }

    /// How good a puzzle is for this kind: more uses first, then variety for mixed and boss
    /// puzzles, and the least else going on for context ones.
    public func score(uses: Int, outside: Int, totalScore: Int) -> Double {
        let u = Double(uses), o = Double(outside)
        switch self {
        case .spotlight, .endless: return u
        case .context: return u * 10 - o * 3
        case .mixed: return u * 10 + min(o, 4) * 5
        case .boss: return u * 10 + o * 5 + Double(totalScore) / 100
        }
    }
}

/// How a puzzle plays out for a chapter: whether it's solvable with the allowed techniques, and
/// how often the focus techniques are the bottleneck.
public struct CampaignAnalysis: Sendable {
    /// Solved by the allowed techniques alone.
    public var solved: Bool
    /// Placements whose bottleneck is a focus technique.
    public var uses: Int
    /// Non-routine, non-focus techniques that were a bottleneck at least once.
    public var outside: Set<Technique>
    /// The outside techniques needed after the first use (all a mid-solve start shows).
    public var outsideAfterFirstUse: Set<Technique>
    /// Empty cells left when the allowed techniques got stuck (0 when solved).
    public var stuckEmpty: Int
    /// Sum of step scores.
    public var totalScore: Int
    /// The position just before the first use (the start of its segment), for mid-solve starts.
    public var beforeFirstUse: Board?

    /// Solves `board` with `allowed` and splits the solve into segments that each end with a
    /// placement; a segment's bottleneck is its hardest technique.
    public static func analyze(_ board: Board, allowed: Set<Technique>, focus: Set<Technique>,
                               routine: Set<Technique>) -> CampaignAnalysis {
        let solver = HumanSolver(allowing: allowed)
        var b = board
        var segmentStart = b
        var hardest: Technique?
        var uses = 0
        var outside = Set<Technique>()
        var outsideLater = Set<Technique>()
        var total = 0
        var first: Board?
        var steps = 0
        while !b.isSolved, steps < 2000, let s = solver.nextStep(b) {
            steps += 1
            total += s.technique.score
            if hardest.map({ s.technique.score > $0.score }) ?? true { hardest = s.technique }
            b.apply(s)
            if !s.placements.isEmpty, let h = hardest {
                if focus.contains(h) {
                    uses += 1
                    if first == nil { first = segmentStart }
                } else if !routine.contains(h) {
                    outside.insert(h)
                    if first != nil { outsideLater.insert(h) }
                }
                hardest = nil
                segmentStart = b
            }
        }
        return CampaignAnalysis(solved: b.isSolved, uses: uses, outside: outside, outsideAfterFirstUse: outsideLater, stuckEmpty: b.emptyCells.count, totalScore: total, beforeFirstUse: first)
    }
}

/// One bundled campaign puzzle.
public struct CampaignPuzzle: Hashable, Sendable {
    public var chapter: String
    public var kind: CampaignKind
    /// The family member a spotlight puzzle is dedicated to.
    public var member: Technique?
    /// The original givens.
    public var puzzle: Grid
    /// Mid-solve starts: givens plus the digits placed so far, and every empty cell's candidates.
    public var values: Grid?
    public var candidates: [DigitMask]?
    public var uses: Int
    public var outside: [Technique]
    public var totalScore: Int

    public init(chapter: String, kind: CampaignKind, member: Technique?, puzzle: Grid, values: Grid? = nil,
                candidates: [DigitMask]? = nil, uses: Int, outside: [Technique], totalScore: Int) {
        self.chapter = chapter
        self.kind = kind
        self.member = member
        self.puzzle = puzzle
        self.values = values
        self.candidates = candidates
        self.uses = uses
        self.outside = outside
        self.totalScore = totalScore
    }

    public var startsMidSolve: Bool { values != nil }
    public var clueCount: Int { (0..<81).filter { puzzle[$0] != 0 }.count }
    public var score: Double { kind.score(uses: uses, outside: outside.count, totalScore: totalScore) }
    public var givens: CellSet { CellSet((0..<81).filter { puzzle[$0] != 0 }) }

    /// The starting position: mid-solve with candidates, or the givens with all candidates.
    public var board: Board {
        if let values, let candidates { return Board(values: values.cells, candidates: candidates, givens: givens) }
        return Board(puzzle)
    }

    /// Re-analyzes the puzzle from its start, for checking the bundled file.
    public func analysis() -> CampaignAnalysis? {
        guard let ch = CampaignChapter.named(chapter) else { return nil }
        return CampaignAnalysis.analyze(board, allowed: ch.allowed(kind, member: member),
                                        focus: ch.focusTechniques(kind, member: member), routine: ch.routine)
    }

    /// The same puzzle relabeled and reshuffled.
    public func transformed(by t: GridTransform) -> CampaignPuzzle {
        var p = self
        p.puzzle = t.apply(puzzle)
        p.values = values.map { t.apply($0) }
        if let candidates {
            let map = t.cellMap
            var out = [DigitMask](repeating: 0, count: 81)
            for src in 0..<81 {
                var m: DigitMask = 0
                for d in Mask.digits(candidates[src]) { m |= Mask.bit(Int(t.digitMap[d])) }
                out[map[src]] = m
            }
            p.candidates = out
        }
        return p
    }
}

/// Encoded as `{"ch", "k", "m"?, "p", "v"?, "c"?, "u", "o", "s"}`, grids as 81-character strings
/// and candidates as three hex digits per cell.
extension CampaignPuzzle: Codable {
    enum CodingKeys: String, CodingKey { case ch, k, m, p, v, c, u, o, s }

    public init(from decoder: Decoder) throws {
        let k = try decoder.container(keyedBy: CodingKeys.self)
        func grid(_ key: CodingKeys) throws -> Grid? {
            guard let s = try k.decodeIfPresent(String.self, forKey: key) else { return nil }
            guard let g = Grid(s) else {
                throw DecodingError.dataCorruptedError(forKey: key, in: k, debugDescription: "Not an 81-cell grid")
            }
            return g
        }
        chapter = try k.decode(String.self, forKey: .ch)
        kind = try k.decode(CampaignKind.self, forKey: .k)
        member = try k.decodeIfPresent(Technique.self, forKey: .m)
        guard let p = try grid(.p) else {
            throw DecodingError.dataCorruptedError(forKey: .p, in: k, debugDescription: "Missing givens")
        }
        puzzle = p
        values = try grid(.v)
        if let hex = try k.decodeIfPresent(String.self, forKey: .c) {
            guard let c = CandidateHex.decode(hex) else {
                throw DecodingError.dataCorruptedError(forKey: .c, in: k, debugDescription: "Expected 243 hex digits")
            }
            candidates = c
        }
        uses = try k.decode(Int.self, forKey: .u)
        outside = try k.decode([Technique].self, forKey: .o)
        totalScore = try k.decode(Int.self, forKey: .s)
    }

    public func encode(to encoder: Encoder) throws {
        var k = encoder.container(keyedBy: CodingKeys.self)
        try k.encode(chapter, forKey: .ch)
        try k.encode(kind, forKey: .k)
        try k.encodeIfPresent(member, forKey: .m)
        try k.encode(puzzle.string, forKey: .p)
        try k.encodeIfPresent(values?.string, forKey: .v)
        try k.encodeIfPresent(candidates.map(CandidateHex.encode), forKey: .c)
        try k.encode(uses, forKey: .u)
        try k.encode(outside, forKey: .o)
        try k.encode(totalScore, forKey: .s)
    }
}
