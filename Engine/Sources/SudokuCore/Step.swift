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
