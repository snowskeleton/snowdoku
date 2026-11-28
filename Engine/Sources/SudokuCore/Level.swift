/// Numbered levels inside the headline tiers. Each level adds at most three techniques (pure
/// variants count as one: Finned = Sashimi, Locked = Naked, UR Type 5 = UR Type 2) to everything
/// below it, in the order a player should learn them. A puzzle's level is the smallest level whose
/// techniques solve it (`Rating.techniqueLevel`), bumped to the next tier's first level when the
/// solve is unusually long (`Rating.level`).
///
/// Extreme has no numbered levels: it is the techniques of last resort (forcing chains and nets,
/// Kraken and Mutant Fish), which no other level expects.
///
/// Raw values are stable identifiers (stored in puzzle banks and saved games).
public enum Level: String, CaseIterable, Comparable, Codable, Sendable {
    case beginner1, beginner2
    case easy1, easy2, easy3
    case medium1, medium2, medium3, medium4
    case hard1, hard2, hard3, hard4
    case expert1, expert2, expert3, expert4
    case master1, master2, master3
    case extreme

    /// Position in `allCases`, easiest first.
    public var index: Int { Self.indices[self]! }
    private static let indices = Dictionary(uniqueKeysWithValues: allCases.enumerated().map { ($1, $0) })

    public static func < (a: Level, b: Level) -> Bool { a.index < b.index }

    /// The headline tier the level belongs to.
    public var tier: Difficulty {
        switch self {
        case .beginner1, .beginner2: .beginner
        case .easy1, .easy2, .easy3: .easy
        case .medium1, .medium2, .medium3, .medium4: .medium
        case .hard1, .hard2, .hard3, .hard4: .hard
        case .expert1, .expert2, .expert3, .expert4: .expert
        case .master1, .master2, .master3: .master
        case .extreme: .extreme
        }
    }

    /// The level's number within its tier (1 for the first), nil for Extreme.
    public var number: Int? {
        guard self != .extreme else { return nil }
        return index - Self.levels(in: tier)[0].index + 1
    }

    /// "Medium 3"; Extreme is just "Extreme".
    public var name: String { number.map { "\(tier.name) \($0)" } ?? tier.name }

    /// The techniques this level introduces, in teaching order.
    public var newTechniques: [Technique] {
        switch self {
        case .beginner1: [.fullHouse, .hiddenSingleBox]
        case .beginner2: [.nakedSingle, .hiddenSingleLine]
        case .easy1: [.pointing, .claiming]
        case .easy2: [.lockedPair, .nakedPair, .hiddenPair]
        case .easy3: [.lockedTriple, .nakedTriple, .hiddenTriple]
        case .medium1: [.xWing, .finnedXWing, .sashimiXWing]
        case .medium2: [.skyscraper, .twoStringKite, .turbotFish]
        case .medium3: [.uniqueRectangle1, .uniqueRectangle2, .uniqueRectangle5, .bugPlusOne]
        case .medium4: [.uniqueRectangle4, .nakedQuad, .hiddenQuad]
        case .hard1: [.xyWing, .xyzWing, .remotePair]
        case .hard2: [.wWing, .emptyRectangle]
        case .hard3: [.swordfish, .jellyfish]
        case .hard4: [.uniqueRectangle3, .uniqueRectangle6, .uniqueRectangleMissing]
        case .expert1: [.hiddenRectangle, .avoidableRectangle, .avoidableRectangle2]
        case .expert2: [.simpleColoring, .colorWrap, .multiColoring]
        case .expert3: [.xChain, .xyChain, .wxyzWing]
        case .expert4: [.finnedSwordfish, .sashimiSwordfish, .finnedJellyfish, .sashimiJellyfish, .niceLoop]
        case .master1: [.discontinuousNiceLoop, .aic, .groupedAIC]
        case .master2: [.alsXZ, .alsXYWing, .sueDeCoq]
        case .master3: [.alsChain, .frankenFish, .deathBlossom]
        case .extreme: [.mutantFish, .krakenFish, .cellForcingChain, .unitForcingChain,
                        .forcingContradiction, .forcingNet, .bruteForce]
        }
    }

    /// Every technique a player at this level knows: this level's and all easier levels'.
    public var techniques: Set<Technique> { Self.cumulative[index] }
    private static let cumulative: [Set<Technique>] = {
        var all = Set<Technique>()
        return allCases.map { all.formUnion($0.newTechniques); return all }
    }()

    /// The levels of a tier, easiest first (just `.extreme` for Extreme).
    public static func levels(in tier: Difficulty) -> [Level] { byTier[tier] ?? [] }
    private static let byTier = Dictionary(grouping: allCases, by: \.tier)

    /// The tier's first and last levels.
    public static func first(in tier: Difficulty) -> Level { levels(in: tier).first! }
    public static func highest(in tier: Difficulty) -> Level { levels(in: tier).last! }

    /// The next level up, nil for Extreme.
    public var next: Level? { index + 1 < Self.allCases.count ? Self.allCases[index + 1] : nil }
}

extension Technique: Comparable {
    /// The level that introduces the technique.
    public var level: Level { Self.levels[self]! }
    private static let levels: [Technique: Level] = {
        var map: [Technique: Level] = [:]
        for l in Level.allCases { for t in l.newTechniques { map[t] = l } }
        return map
    }()

    /// Teaching order: by level, then the order the level lists its techniques in. "Easiest first"
    /// everywhere in the app and tools; the solver has its own order (`HumanSolver.allStrategies`).
    public var rank: Int { Self.ranks[self]! }
    private static let ranks: [Technique: Int] = Dictionary(uniqueKeysWithValues:
        Level.allCases.flatMap(\.newTechniques).enumerated().map { ($1, $0) })

    public static func < (a: Technique, b: Technique) -> Bool { a.rank < b.rank }
}
