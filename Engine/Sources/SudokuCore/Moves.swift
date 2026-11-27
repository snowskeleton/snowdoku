/// One conclusion available in a position: a digit to place or a candidate to remove, with every
/// technique that justifies it. A full-house cell, say, is also a naked single and up to three
/// hidden singles; it appears once, labeled with the easiest of them.
public struct Move: Sendable {
    public var candidate: Candidate
    /// True for a placement, false for an elimination.
    public var isPlacement: Bool
    /// Every technique that reaches this conclusion, easiest first (by score, then solver order).
    public var techniques: [Technique]
    /// The easiest step that reaches it.
    public var step: Step

    /// The easiest technique that justifies the move.
    public var technique: Technique { techniques[0] }
}

/// Every move available in a position, across techniques (`HumanSolver.allMoves`).
public struct MoveSet: Sendable {
    /// Each distinct placement once, ordered by cell.
    public var placements: [Move]
    /// Each distinct eliminated candidate once, ordered by cell then digit.
    public var eliminations: [Move]
    /// Every step found, easiest technique first. Steps of one technique that reach the same
    /// conclusions (a hidden single seen from its row and its column) are kept once; the same
    /// conclusion reached by different techniques appears once per technique.
    public var steps: [Step]

    public var isEmpty: Bool { steps.isEmpty }

    /// The placement for `cell`, if some technique places it now.
    public func placement(at cell: Int) -> Move? { placements.first { $0.candidate.cell == cell } }

    /// The distinct steps of one technique.
    public func steps(of technique: Technique) -> [Step] { steps.filter { $0.technique == technique } }
}

extension Step {
    /// The step's conclusions as a comparable key: two steps with the same key do the same thing.
    var conclusionKey: [Int] {
        placements.map { $0.cell * 10 + $0.digit }.sorted() + [-1]
            + eliminations.map { $0.cell * 10 + $0.digit }.sorted()
    }
}

extension HumanSolver {
    /// Every move available right now, across all of this solver's techniques, merged by
    /// conclusion. `tier` caps the techniques tried: by default Expert, because the Master
    /// techniques (ALS chains, exotic fish) cost far more to search exhaustively than all the
    /// others together. Chains and forcing (the `ranked` strategies) are skipped unless
    /// `includeChains` is set, whatever the cap. Typically a few milliseconds.
    public func allMoves(_ board: Board, upTo tier: Difficulty = .expert, includeChains: Bool = false) -> MoveSet {
        var steps: [Step] = []
        struct Key: Hashable { var technique: Technique; var conclusion: [Int] }
        var seen = Set<Key>()
        let chosen = strategies.enumerated()
            .filter { s in (includeChains || !s.element.ranked) && s.element.technique.difficulty <= tier }
            .sorted { ($0.element.technique.score, $0.offset) < ($1.element.technique.score, $1.offset) }
            .map(\.element)
        for s in chosen {
            var out = StepCollector(findAll: true, exhaustive: true)
            s.find(board, &out)
            for step in out.steps where seen.insert(Key(technique: step.technique, conclusion: step.conclusionKey)).inserted { steps.append(step) }
        }

        var placements: [Candidate: Move] = [:]
        var eliminations: [Candidate: Move] = [:]
        func add(_ c: Candidate, _ step: Step, to moves: inout [Candidate: Move], placement: Bool) {
            if moves[c] == nil {
                moves[c] = Move(candidate: c, isPlacement: placement, techniques: [step.technique], step: step)
            } else if !moves[c]!.techniques.contains(step.technique) {
                moves[c]!.techniques.append(step.technique)
            }
        }
        for step in steps {
            for p in step.placements { add(p, step, to: &placements, placement: true) }
            for e in step.eliminations { add(e, step, to: &eliminations, placement: false) }
        }
        let order: (Move, Move) -> Bool = {
            ($0.candidate.cell, $0.candidate.digit) < ($1.candidate.cell, $1.candidate.digit)
        }
        return MoveSet(placements: placements.values.sorted(by: order),
                       eliminations: eliminations.values.sorted(by: order),
                       steps: steps)
    }

    /// The technique a player needed to fill `cell` from `board`: the easiest single that places
    /// it directly; otherwise the hardest technique the solver uses on its way from `board` until
    /// it places that cell, unless some easier technique places it directly (a BUG+1, say).
    /// `.bruteForce` when the known techniques get stuck first; nil when the cell is filled.
    public func placementTechnique(_ board: Board, cell: Int, maxSteps: Int = 500) -> Technique? {
        guard board.isEmpty(cell) else { return nil }
        func placesDirectly(_ s: any Strategy) -> Bool {
            var out = StepCollector(findAll: true)
            s.find(board, &out)
            return out.steps.contains { $0.placements.contains { $0.cell == cell } }
        }
        let singles = strategies.filter { $0.technique.difficulty == .beginner && !$0.ranked }
            .sorted { $0.technique.score < $1.technique.score }
        if let s = singles.first(where: placesDirectly) { return s.technique }

        // Solve on until the cell is placed: an upper bound.
        var b = board
        var hardest: Technique?
        var reached = false
        for _ in 0..<maxSteps {
            guard let s = nextStep(b) else { break }
            if hardest.map({ s.technique.score > $0.score }) ?? true { hardest = s.technique }
            b.apply(s)
            if !b.isEmpty(cell) { reached = true; break }
        }
        var best = reached ? hardest! : .bruteForce
        for s in strategies where s.technique.difficulty > .beginner && s.technique.score < best.score && placesDirectly(s) {
            best = s.technique
        }
        return best
    }
}
