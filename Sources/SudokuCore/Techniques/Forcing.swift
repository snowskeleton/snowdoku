/// Applies naked and hidden singles until nothing changes.
/// Returns nil if the position becomes contradictory.
func propagateSingles(_ start: Board) -> Board? {
    var b = start
    var changed = true
    while changed {
        changed = false
        for c in 0..<81 where b.isEmpty(c) {
            let m = b.candidates[c]
            if m == 0 { return nil }
            if m.nonzeroBitCount == 1 { b.place(c, Mask.first(m)); changed = true }
        }
        for h in 0..<27 {
            var placed: DigitMask = 0
            var once: DigitMask = 0, twice: DigitMask = 0
            for c in Geometry.houses[h] {
                if b.values[c] != 0 {
                    let bit = Mask.bit(b.value(c))
                    if placed & bit != 0 { return nil }
                    placed |= bit
                } else {
                    let m = b.candidates[c]
                    twice |= once & m
                    once |= m
                }
            }
            if placed | once != Mask.all { return nil }
            let singles = once & ~twice & ~placed
            for d in Mask.digits(singles) {
                if let c = Geometry.houses[h].first(where: { b.has($0, d) }) {
                    b.place(c, d)
                    changed = true
                }
            }
        }
    }
    return b
}

/// Forcing chains/nets built on single propagation. These are the "extreme" backstop that let
/// almost every puzzle be solved without guessing.
struct ForcingChain: Strategy {
    enum Kind: Sendable { case cell, unit, contradiction }
    let kind: Kind
    var net = false
    var technique: Technique {
        if net { return .forcingNet }
        switch kind {
        case .cell: return .cellForcingChain
        case .unit: return .unitForcingChain
        case .contradiction: return .forcingContradiction
        }
    }

    func assume(_ b: Board, _ c: Int, _ d: Int) -> Board? {
        var x = b
        x.place(c, d)
        return net ? propagateNet(x) : propagateSingles(x)
    }

    /// Conclusions shared by every branch.
    func common(_ branches: [Board], _ b: Board) -> ([Candidate], [Candidate]) {
        var places: [Candidate] = []
        var elims: [Candidate] = []
        for c in 0..<81 where b.isEmpty(c) {
            let v = branches[0].value(c)
            if v != 0 && branches.allSatisfy({ $0.value(c) == v }) {
                places.append(Candidate(c, v))
                continue
            }
            for d in Mask.digits(b.candidates[c]) {
                // Eliminated in every branch (not a candidate and not placed as d).
                if branches.allSatisfy({ !$0.has(c, d) && $0.value(c) != d }) { elims.append(Candidate(c, d)) }
            }
        }
        return (places, elims)
    }

    func find(_ b: Board, _ out: inout StepCollector) {
        switch kind {
        case .contradiction:
            for c in 0..<81 where b.isEmpty(c) {
                for d in Mask.digits(b.candidates[c]) where assume(b, c, d) == nil {
                    out.add(Step(technique, eliminations: [Candidate(c, d)], houses: Geometry.housesOfCell[c],
                                 highlights: [Highlight(c, d, .pattern)],
                                 explanation: "Assume \(Geometry.cellName(c)) is \(d). Following the consequences leads to a contradiction, so \(Geometry.cellName(c)) can't be \(d)."))
                    if out.done { return }
                }
            }
        case .cell:
            for n in 2...3 {
                for c in 0..<81 where b.isEmpty(c) && b.candidates[c].nonzeroBitCount == n {
                    let ds = Mask.digits(b.candidates[c])
                    let branches = ds.compactMap { assume(b, c, $0) }
                    guard branches.count == ds.count else { continue }
                    let (places, elims) = common(branches, b)
                    guard !places.isEmpty || !elims.isEmpty else { continue }
                    let step = Step(technique, placements: places, eliminations: elims, houses: Geometry.housesOfCell[c],
                                    highlights: ds.map { Highlight(c, $0, .pattern) },
                                    complexity: n,
                                    explanation: "Try each candidate of \(Geometry.cellName(c)) (\(ds.map(String.init).joined(separator: "/"))). Every choice leads to the same result: \(Step(technique, placements: places, eliminations: elims, explanation: "").conclusion).")
                    out.add(step)
                    if out.done { return }
                }
            }
        case .unit:
            for n in 2...3 {
                for h in 0..<27 {
                    for d in 1...9 {
                        let pos = b.positions(d, h)
                        guard pos.count == n else { continue }
                        let branches = pos.compactMap { assume(b, $0, d) }
                        guard branches.count == pos.count else { continue }
                        let (places, elims) = common(branches, b)
                        guard !places.isEmpty || !elims.isEmpty else { continue }
                        out.add(Step(technique, placements: places, eliminations: elims, houses: [h],
                                     highlights: pos.map { Highlight($0, d, .pattern) },
                                     complexity: n,
                                     explanation: "\(d) must go in one of \(Geometry.cellsName(pos)) in \(Geometry.houseName(h)). Each option leads to the same result: \(Step(technique, placements: places, eliminations: elims, explanation: "").conclusion)."))
                        if out.done { return }
                    }
                }
            }
        }
    }
}

/// Stronger propagation: singles plus locked candidates and naked/hidden pairs, to a fixpoint.
func propagateNet(_ start: Board) -> Board? {
    let helpers: [any Strategy] = [Pointing(), Claiming(), NakedSubset(size: 2), HiddenSubset(size: 2)]
    guard var b = propagateSingles(start) else { return nil }
    while true {
        var changed = false
        for h in helpers {
            var out = StepCollector(findAll: true)
            h.find(b, &out)
            for s in out.steps { for e in s.eliminations where b.eliminate(e.cell, e.digit) { changed = true } }
        }
        guard changed else { return b }
        guard let next = propagateSingles(b) else { return nil }
        b = next
    }
}

/// Forcing chains using the stronger net propagation.
struct ForcingNet: Strategy {
    let technique = Technique.forcingNet
    func find(_ b: Board, _ out: inout StepCollector) {
        for kind in [ForcingChain.Kind.contradiction, .cell, .unit] {
            ForcingChain(kind: kind, net: true).find(b, &out)
            if out.done { return }
        }
    }
}
