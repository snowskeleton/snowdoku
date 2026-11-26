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

/// Forcing chains and nets, found by tabling (see `ImplicationTable`), so every step shows the
/// chains that prove it.
///
/// - Cell / unit forcing chain: each candidate of a cell (or each place for a digit in a house)
///   leads to the same conclusion.
/// - Forcing chain contradiction: assuming a candidate is true (or false) leads to a contradiction.
///
/// In chain mode every inference follows a strong or weak link of the position; `net` allows
/// inferences that rest on several earlier conclusions at once (reported as a Forcing Net).
struct ForcingChain: Strategy {
    enum Kind: Sendable { case cell, unit, contradiction }
    let kind: Kind
    var net = false
    var ranked: Bool { true }
    var technique: Technique {
        if net { return .forcingNet }
        switch kind {
        case .cell: return .cellForcingChain
        case .unit: return .unitForcingChain
        case .contradiction: return .forcingContradiction
        }
    }

    func find(_ b: Board, _ out: inout StepCollector) {
        var cache = TableCache(b, net: net)
        find(b, &cache, &out)
    }

    func find(_ b: Board, _ cache: inout TableCache, _ out: inout StepCollector) {
        switch kind {
        case .contradiction:
            for c in 0..<81 where b.isEmpty(c) {
                for d in Mask.digits(b.candidates[c]) {
                    for on in [true, false] {
                        let t = cache.table(Literal(c, d, on: on))
                        guard let conflict = t.conflict else { continue }
                        out.add(contradictionStep(t, conflict, b))
                        if out.done { return }
                    }
                }
            }
        case .cell:
            for c in 0..<81 where b.isEmpty(c) && (2...4).contains(b.candidates[c].nonzeroBitCount) {
                let starts = Mask.digits(b.candidates[c]).map { Literal(c, $0, on: true) }
                if let step = commonStep(starts, b, &cache, houses: Geometry.housesOfCell[c],
                                         intro: "Try each candidate of \(Geometry.cellName(c)) (\(Mask.digits(b.candidates[c]).map(String.init).joined(separator: "/"))).") {
                    out.add(step)
                    if out.done { return }
                }
            }
        case .unit:
            for h in 0..<27 {
                for d in 1...9 {
                    let pos = b.positions(d, h)
                    guard (2...4).contains(pos.count) else { continue }
                    let starts = pos.map { Literal($0, d, on: true) }
                    if let step = commonStep(starts, b, &cache, houses: [h],
                                             intro: "\(d) must go in one of \(Geometry.cellsName(pos)) in \(Geometry.houseName(h)).") {
                        out.add(step)
                        if out.done { return }
                    }
                }
            }
        }
    }

    private var kindName: String { net ? "Forcing Net" : "Forcing Chain" }

    private func contradictionStep(_ t: ImplicationTable, _ conflict: [Literal], _ b: Board) -> Step {
        let s = t.start
        let paths = conflict.map { t.derivation(of: [$0]) }
        let all = t.derivation(of: conflict)
        let shown = paths.map { "\(t.describe($0))." }.joined(separator: " ")
        let conclusion: String
        let step: Step
        if s.on {
            conclusion = "\(Geometry.cellName(s.cell)) can't be \(s.digit)"
        } else {
            conclusion = "\(Geometry.cellName(s.cell)) must be \(s.digit)"
        }
        let text = "\(kindName) Contradiction: assume \(s). \(shown) Then \(t.conflictText), which is impossible, so \(conclusion)."
        step = Step(technique,
                    placements: s.on ? [] : [s.candidate],
                    eliminations: s.on ? [s.candidate] : [],
                    houses: Geometry.housesOfCell[s.cell],
                    highlights: [Highlight(s.cell, s.digit, .pattern)] + ImplicationTable.highlights(all.dropFirst().map { $0 }),
                    links: t.links(all),
                    complexity: ImplicationTable.length(all),
                    explanation: text)
        return step
    }

    /// The best conclusion shared by every branch, with the chain from each branch to it.
    /// Placements beat eliminations; then the shortest total proof wins.
    private func commonStep(_ starts: [Literal], _ b: Board, _ cache: inout TableCache, houses: [Int], intro: String) -> Step? {
        let tables = starts.map { cache.table($0) }
        guard tables.allSatisfy({ $0.conflict == nil }) else { return nil }
        let startCells = Set(starts.map(\.cell))
        var best: (lit: Literal, cost: Int)?
        for l in tables[0].order.dropFirst() where tables.dropFirst().allSatisfy({ $0.has(l) }) {
            // A conclusion about one of the starting cells is just the premise in disguise.
            if startCells.contains(l.cell) && starts.contains(where: { $0.digit == l.digit }) { continue }
            if l.on ? !b.isEmpty(l.cell) : !b.has(l.cell, l.digit) { continue }
            let cost = tables.reduce(0) { $0 + $1.depthOf(l) }
            if let cur = best {
                if cur.lit.on && !l.on { continue }
                if cur.lit.on == l.on && cur.cost <= cost { continue }
            }
            best = (l, cost)
        }
        guard let (target, cost) = best else { return nil }
        var hl: [Highlight] = starts.map { Highlight($0.cell, $0.digit, .pattern) }
        var links: [ChainLink] = []
        var branches: [String] = []
        for t in tables {
            let path = t.derivation(of: [target])
            hl += ImplicationTable.highlights(path.dropFirst().map { $0 })
            links += t.links(path)
            branches.append("If \(t.describe(path)).")
        }
        let conclusion = target.on ? "place \(target.candidate)" : describeEliminations([target.candidate])
        let name = net ? "Forcing Net" : technique.name
        return Step(technique,
                    placements: target.on ? [target.candidate] : [],
                    eliminations: target.on ? [] : [target.candidate],
                    houses: houses, highlights: hl, links: links, complexity: cost,
                    explanation: "\(name): \(intro) \(branches.joined(separator: " ")) Every option leads to \(target), so \(conclusion).")
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

/// Forcing nets: tabled nets first (each step explained), then, as a last resort before guessing,
/// branches that also use locked candidates and pairs (explained in summary only).
struct ForcingNet: Strategy {
    let technique = Technique.forcingNet
    var ranked: Bool { true }

    func find(_ b: Board, _ out: inout StepCollector) {
        var cache = TableCache(b, net: true)
        for kind in [ForcingChain.Kind.contradiction, .cell, .unit] {
            ForcingChain(kind: kind, net: true).find(b, &cache, &out)
        }
        guard out.steps.isEmpty else { return }
        deepNet(b, &out)
    }

    func assume(_ b: Board, _ c: Int, _ d: Int) -> Board? {
        var x = b
        x.place(c, d)
        return propagateNet(x)
    }

    /// Conclusions shared by every branch.
    func common(_ branches: [Board], _ b: Board) -> ([Candidate], [Candidate]) {
        var places: [Candidate] = [], elims: [Candidate] = []
        for c in 0..<81 where b.isEmpty(c) {
            for d in Mask.digits(b.candidates[c]) {
                if branches.allSatisfy({ $0.value(c) == d }) { places.append(Candidate(c, d)) }
                else if branches.allSatisfy({ !$0.has(c, d) && $0.value(c) != d }) { elims.append(Candidate(c, d)) }
            }
        }
        return (places, elims)
    }

    func deepNet(_ b: Board, _ out: inout StepCollector) {
        let tail = "Following each one with singles, locked candidates and pairs"
        for c in 0..<81 where b.isEmpty(c) {
            for d in Mask.digits(b.candidates[c]) where assume(b, c, d) == nil {
                out.add(Step(technique, eliminations: [Candidate(c, d)], houses: Geometry.housesOfCell[c],
                             highlights: [Highlight(c, d, .pattern)], complexity: 1000,
                             explanation: "Forcing Net: assume \(Geometry.cellName(c)) is \(d). \(tail) leads to a contradiction, so \(Geometry.cellName(c)) can't be \(d)."))
                return  // Each branch is expensive; the first find is enough.
            }
        }
        guard out.steps.isEmpty else { return }
        for c in 0..<81 where b.isEmpty(c) && (2...3).contains(b.candidates[c].nonzeroBitCount) {
            let ds = Mask.digits(b.candidates[c])
            let branches = ds.compactMap { assume(b, c, $0) }
            guard branches.count == ds.count else { continue }
            let (places, elims) = common(branches, b)
            guard !places.isEmpty || !elims.isEmpty else { continue }
            out.add(Step(technique, placements: places, eliminations: elims, houses: Geometry.housesOfCell[c],
                         highlights: ds.map { Highlight(c, $0, .pattern) }, complexity: 1000 + ds.count,
                         explanation: "Forcing Net: try each candidate of \(Geometry.cellName(c)) (\(ds.map(String.init).joined(separator: "/"))). \(tail), every choice leads to the same result: \(Step(technique, placements: places, eliminations: elims, explanation: "").conclusion)."))
            return
        }
        guard out.steps.isEmpty else { return }
        for h in 0..<27 {
            for d in 1...9 {
                let pos = b.positions(d, h)
                guard (2...3).contains(pos.count) else { continue }
                let branches = pos.compactMap { assume(b, $0, d) }
                guard branches.count == pos.count else { continue }
                let (places, elims) = common(branches, b)
                guard !places.isEmpty || !elims.isEmpty else { continue }
                out.add(Step(technique, placements: places, eliminations: elims, houses: [h],
                             highlights: pos.map { Highlight($0, d, .pattern) }, complexity: 1000 + pos.count,
                             explanation: "Forcing Net: \(d) must go in one of \(Geometry.cellsName(pos)) in \(Geometry.houseName(h)). \(tail), each option leads to the same result: \(Step(technique, placements: places, eliminations: elims, explanation: "").conclusion)."))
                return
            }
        }
    }
}
