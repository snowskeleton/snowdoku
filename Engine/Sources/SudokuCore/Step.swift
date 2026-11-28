/// A single candidate: digit `digit` in cell `cell`.
public struct Candidate: Hashable, Sendable, Codable, CustomStringConvertible {
    public var cell: Int
    public var digit: Int
    public init(_ cell: Int, _ digit: Int) { self.cell = cell; self.digit = digit }
    public var description: String { "\(Geometry.cellName(cell))=\(digit)" }
}

/// Something to draw on the board when presenting a step.
public struct Highlight: Hashable, Sendable {
    public enum Role: Hashable, Sendable {
        case pattern      // core pattern candidates/cells
        case secondary    // supporting cells (e.g. pincers, cover)
        case fin
        case colorA, colorB, colorC, colorD
        case chainOn      // candidate that is true in the chain's logic
        case chainOff     // candidate that is false in the chain's logic
    }
    public var cell: Int
    /// 0 means "the whole cell".
    public var digit: Int
    public var role: Role
    public init(_ cell: Int, _ digit: Int, _ role: Role) { self.cell = cell; self.digit = digit; self.role = role }
}

/// A link between two (possibly grouped) chain nodes, for drawing arrows.
public struct ChainLink: Hashable, Sendable {
    public var from: [Candidate]
    public var to: [Candidate]
    public var isStrong: Bool
}

/// One logical deduction found by a technique.
public struct Step: Sendable {
    public var technique: Technique
    public var placements: [Candidate]
    public var eliminations: [Candidate]
    /// Houses the pattern lives in (used for "where to look" hints).
    public var houses: [Int]
    public var highlights: [Highlight]
    public var links: [ChainLink]
    /// Full human-readable explanation of the deduction.
    public var explanation: String
    /// Secondary ordering among steps of the same technique (e.g. chain length). Lower is nicer.
    public var complexity: Int

    public init(_ technique: Technique,
                placements: [Candidate] = [],
                eliminations: [Candidate] = [],
                houses: [Int] = [],
                highlights: [Highlight] = [],
                links: [ChainLink] = [],
                complexity: Int = 0,
                explanation: String) {
        self.technique = technique
        self.placements = placements
        self.eliminations = eliminations
        self.houses = houses
        self.highlights = highlights
        self.links = links
        self.complexity = complexity
        self.explanation = explanation
    }

    /// What this step adds to a puzzle's total score (`Rating.totalScore`): the technique's score,
    /// plus a surcharge for a long chain. Chains have no length limit, since the solver always picks
    /// the shortest one available, but a long chain is harder to find and follow than a short one, so
    /// each link beyond `Step.freeChainLinks` adds `Step.pointsPerExtraLink`. A long enough chain
    /// also raises the step's tier (`difficulty`).
    public var score: Int {
        guard technique.isChain, links.count > Self.freeChainLinks else { return technique.score }
        return technique.score + (links.count - Self.freeChainLinks) * Self.pointsPerExtraLink
    }
    /// The tier of this step: its technique's, except that a long chain counts as harder, by the tier
    /// of its `score` (so an X-Chain of 14 links or more, or an XY-Chain of 12, is a Master move). A
    /// chain is never more than Master: Extreme is for forcing chains and nets.
    public var difficulty: Difficulty {
        let base = technique.difficulty
        guard technique.isChain else { return base }
        return max(base, min(.master, Difficulty(score: score)))
    }
    /// Links a chain can have before it costs extra (most chains the solver picks have 5–9).
    public static let freeChainLinks = 9
    public static let pointsPerExtraLink = 10

    /// Cells involved in the pattern itself (not the targets).
    public var patternCells: CellSet { CellSet(highlights.map(\.cell)) }
    /// Cells affected by the step.
    public var targetCells: CellSet { CellSet(placements.map(\.cell) + eliminations.map(\.cell)) }

    /// Human-readable conclusion, e.g. "r1c2=5" or "remove 4 from r1c2, r3c3".
    public var conclusion: String {
        var parts: [String] = []
        if !placements.isEmpty { parts.append("place " + placements.map(\.description).joined(separator: ", ")) }
        if !eliminations.isEmpty { parts.append(describeEliminations(eliminations)) }
        return parts.joined(separator: "; ")
    }
}

func describeEliminations(_ e: [Candidate]) -> String {
    var byDigit: [Int: [Int]] = [:]
    for c in e { byDigit[c.digit, default: []].append(c.cell) }
    return byDigit.keys.sorted().map { d in
        "remove \(d) from \(Geometry.cellsName(byDigit[d]!.sorted()))"
    }.joined(separator: "; ")
}

/// Collects steps from a strategy. In first-only mode, strategies stop after the first hit.
public struct StepCollector {
    public let findAll: Bool
    /// Every instance, not just the simplest few: ranked strategies may otherwise skip ones they
    /// can tell won't beat what they already have (drills need them all).
    public let exhaustive: Bool
    public private(set) var steps: [Step] = []
    public init(findAll: Bool, exhaustive: Bool = false) { self.findAll = findAll; self.exhaustive = exhaustive && findAll }
    public var done: Bool { !findAll && !steps.isEmpty }
    public mutating func add(_ s: Step) {
        guard !s.placements.isEmpty || !s.eliminations.isEmpty else { return }
        steps.append(s)
    }
}

/// A finder for exactly one technique.
public protocol Strategy: Sendable {
    var technique: Technique { get }
    /// When true the solver gathers all steps and presents the simplest (lowest complexity).
    var ranked: Bool { get }
    func find(_ board: Board, _ out: inout StepCollector)
}

extension Strategy {
    public var ranked: Bool { false }
}

func cands(_ cells: [Int], _ d: Int) -> [Candidate] { cells.map { Candidate($0, d) } }
