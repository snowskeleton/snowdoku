/// An Almost Locked Set: N cells in one house holding exactly N+1 candidates.
struct ALSet {
    let cells: CellSet
    let list: [Int]
    let digits: DigitMask
    let byDigit: [CellSet]   // index 1...9
    /// Per digit, the cells outside the set holding it that see all of the set's instances.
    let seen: [CellSet]
    let house: Int

    var name: String { "\(Geometry.cellsName(list)) {\(Mask.digits(digits).map(String.init).joined())}" }
}

/// ALS Chain's search limits: at most this many sets, and this many search nodes per position.
let alsChainMaxLength = 5
let alsChainBudget = 400_000

/// Every ALS on the board. With no size limit (an empty house of n cells can hold ALSs of up to
/// n - 1 cells): the big ones are what HoDoKu finds and we used to miss, and they cost little.
func findALS(_ b: Board, maxSize: Int = 8) -> [ALSet] {
    var seen = Set<CellSet>()
    var result: [ALSet] = []
    for h in 0..<27 {
        let empty = Geometry.houses[h].filter { b.isEmpty($0) }
        for k in 1...max(1, min(maxSize, empty.count)) where k <= empty.count {
            forEachCombination(empty.count, k) { idx in
                let cells = idx.map { empty[$0] }
                let u = b.union(cells)
                guard u.nonzeroBitCount == k + 1 else { return true }
                let set = CellSet(cells)
                guard seen.insert(set).inserted else { return true }
                var by = Array(repeating: CellSet(), count: 10)
                var seen = by
                for d in Mask.digits(u) {
                    by[d] = CellSet(cells.filter { b.has($0, d) })
                    seen[d] = b.filter(Geometry.commonPeers(by[d]), d) - set
                }
                result.append(ALSet(cells: set, list: cells, digits: u, byDigit: by, seen: seen, house: h))
                return true
            }
        }
    }
    return result
}

/// Digits that are restricted common candidates of two non-overlapping ALSs:
/// every instance in A sees every instance in B.
func restrictedCommons(_ a: ALSet, _ b: ALSet) -> DigitMask {
    guard a.cells.isDisjoint(with: b.cells) else { return 0 }
    var r: DigitMask = 0
    for d in Mask.digits(a.digits & b.digits) {
        let bx = b.byDigit[d]
        if a.byDigit[d].allSatisfy({ bx.isSubset(of: Geometry.peerSets[$0]) }) { r |= Mask.bit(d) }
    }
    return r
}

func alsHighlights(_ sets: [ALSet], _ b: Board) -> [Highlight] {
    let roles: [Highlight.Role] = [.colorA, .colorB, .colorC, .colorD]
    var hl: [Highlight] = []
    for (i, s) in sets.enumerated() {
        for c in s.list { for d in Mask.digits(b.candidates[c]) { hl.append(Highlight(c, d, roles[i % 4])) } }
    }
    return hl
}

struct ALSXZ: Strategy {
    let technique = Technique.alsXZ
    func find(_ b: Board, _ out: inout StepCollector) {
        let sets = findALS(b)
        for i in 0..<sets.count {
            for j in (i + 1)..<max(i + 1, sets.count) {
                let A = sets[i], B = sets[j]
                let rcc = restrictedCommons(A, B)
                guard rcc != 0 else { continue }
                if rcc.nonzeroBitCount >= 2 {
                    doublyLinked(A, B, rcc, b, &out)
                    if out.done { return }
                    continue
                }
                for x in Mask.digits(rcc) {
                    var elims: [Candidate] = []
                    for z in Mask.digits(A.digits & B.digits & ~Mask.bit(x)) {
                        let zc = A.byDigit[z] | B.byDigit[z]
                        elims += b.filter(Geometry.commonPeers(zc) - A.cells - B.cells, z).map { Candidate($0, z) }
                    }
                    guard !elims.isEmpty else { continue }
                    out.add(Step(technique, eliminations: elims, houses: [A.house, B.house], highlights: alsHighlights([A, B], b),
                                 explanation: "ALS-XZ: \(A.name) and \(B.name) are almost locked sets sharing the restricted common \(x) (it can be in only one of them). So one of them becomes locked, and any common digit must appear in the cells it touches: \(describeEliminations(elims))."))
                    if out.done { return }
                }
            }
        }
    }
}

extension ALSXZ {
    /// Two restricted commons: neither ALS can give up both (it would have too few digits for its
    /// cells), and each common can sit in only one of them, so each ALS keeps exactly one common and
    /// all its other digits. Both ALSs are then locked sets.
    func doublyLinked(_ A: ALSet, _ B: ALSet, _ rcc: DigitMask, _ b: Board, _ out: inout StepCollector) {
        var elims = Set<Candidate>()
        let both = A.cells | B.cells
        for x in Mask.digits(rcc) {
            for c in b.filter(Geometry.commonPeers(A.byDigit[x] | B.byDigit[x]) - both, x) { elims.insert(Candidate(c, x)) }
        }
        for s in [A, B] {
            for d in Mask.digits(s.digits & ~rcc) {
                for c in b.filter(Geometry.commonPeers(s.byDigit[d]) - s.cells, d) { elims.insert(Candidate(c, d)) }
            }
        }
        guard !elims.isEmpty else { return }
        let list = elims.sorted { ($0.cell, $0.digit) < ($1.cell, $1.digit) }
        let xs = Mask.digits(rcc).map(String.init).joined(separator: " and ")
        out.add(Step(technique, eliminations: list, houses: [A.house, B.house], highlights: alsHighlights([A, B], b),
                     explanation: "Doubly linked ALS-XZ: \(A.name) and \(B.name) are almost locked sets sharing two restricted commons, \(xs) (each can be in only one of them). Neither set can lose both, or it would have too few digits for its cells, so each keeps one of them and every other digit it holds: both become locked sets. \(xs) must go in their cells, and each set's other digits stay inside it: \(describeEliminations(list))."))
    }
}

struct ALSXYWing: Strategy {
    let technique = Technique.alsXYWing
    func find(_ b: Board, _ out: inout StepCollector) {
        let sets = findALS(b)
        var nbrs: [[(Int, DigitMask)]] = Array(repeating: [], count: sets.count)
        for i in 0..<sets.count {
            for j in (i + 1)..<max(i + 1, sets.count) {
                let r = restrictedCommons(sets[i], sets[j])
                if r != 0 { nbrs[i].append((j, r)); nbrs[j].append((i, r)) }
            }
        }
        for c in 0..<sets.count {
            let list = nbrs[c]
            for p in 0..<list.count {
                for q in (p + 1)..<max(p + 1, list.count) {
                    let (ai, ar) = list[p], (bi, br) = list[q]
                    let A = sets[ai], B = sets[bi], C = sets[c]
                    guard A.cells.isDisjoint(with: B.cells) else { continue }
                    for x in Mask.digits(ar) {
                        for y in Mask.digits(br) where y != x {
                            var elims: [Candidate] = []
                            for z in Mask.digits(A.digits & B.digits & ~Mask.bit(x) & ~Mask.bit(y)) {
                                let zc = A.byDigit[z] | B.byDigit[z]
                                elims += b.filter(Geometry.commonPeers(zc) - A.cells - B.cells - C.cells, z).map { Candidate($0, z) }
                            }
                            guard !elims.isEmpty else { continue }
                            out.add(Step(technique, eliminations: elims, houses: [A.house, B.house, C.house], highlights: alsHighlights([C, A, B], b),
                                         explanation: "ALS-XY-Wing: pivot ALS \(C.name) links to \(A.name) via \(x) and to \(B.name) via \(y). Either way, one of the wings becomes locked: \(describeEliminations(elims))."))
                            if out.done { return }
                        }
                    }
                }
            }
        }
    }
}

struct DeathBlossom: Strategy {
    let technique = Technique.deathBlossom
    func find(_ b: Board, _ out: inout StepCollector) {
        let sets = findALS(b)
        for stem in 0..<81 where b.isEmpty(stem) && (2...3).contains(b.candidates[stem].nonzeroBitCount) {
            let sd = Mask.digits(b.candidates[stem])
            var petals: [[Int]] = []
            for d in sd {
                petals.append(sets.indices.filter { i in
                    let s = sets[i]
                    return !s.cells.contains(stem) && s.digits & Mask.bit(d) != 0 && s.byDigit[d].isSubset(of: Geometry.peerSets[stem])
                })
            }
            guard petals.allSatisfy({ !$0.isEmpty }) else { continue }
            var choice: [Int] = []
            func recurse(_ k: Int, _ used: CellSet, _ common: DigitMask) -> Bool {
                if k == sd.count {
                    let zs = common & ~b.candidates[stem]
                    for z in Mask.digits(zs) {
                        var zc = CellSet()
                        for i in choice { zc |= sets[i].byDigit[z] }
                        let elims = b.filter(Geometry.commonPeers(zc) - used - CellSet([stem]), z).map { Candidate($0, z) }
                        guard !elims.isEmpty else { continue }
                        let ps = choice.map { sets[$0] }
                        out.add(Step(technique, eliminations: elims, highlights: [Highlight(stem, 0, .pattern)] + alsHighlights(ps, b),
                                     explanation: "Death Blossom: stem \(Geometry.cellName(stem)) has candidates \(sd.map(String.init).joined(separator: "/")). Each choice locks one petal (\(ps.map(\.name).joined(separator: "; "))), and every petal then holds \(z): \(describeEliminations(elims))."))
                        if out.done { return false }
                    }
                    return true
                }
                for i in petals[k] where sets[i].cells.isDisjoint(with: used) {
                    let nc = common & sets[i].digits
                    if nc & ~b.candidates[stem] == 0 { continue }
                    choice.append(i)
                    let cont = recurse(k + 1, used | sets[i].cells, nc)
                    choice.removeLast()
                    if !cont { return false }
                }
                return true
            }
            if !recurse(0, CellSet(), Mask.all) { return }
        }
    }
}

/// Chains of 4 or more ALSs linked by restricted common candidates (shorter ones are ALS-XZ /
/// ALS-XY-Wing). Neighbors in the chain must not overlap, but other sets may: if a target cell
/// held z, the first set would lose z and so hold the first link's digit, which pushes each set in
/// turn onto its next link's digit, until the last set loses both its link digit and z.
struct ALSChain: Strategy {
    let technique = Technique.alsChain

    func find(_ b: Board, _ out: inout StepCollector) {
        let sets = findALS(b)
        var nbrs: [[(Int, DigitMask)]] = Array(repeating: [], count: sets.count)
        for i in 0..<sets.count {
            for j in (i + 1)..<max(i + 1, sets.count) {
                let r = restrictedCommons(sets[i], sets[j])
                if r != 0 { nbrs[i].append((j, r)); nbrs[j].append((i, r)) }
            }
        }
        // Find-all mode (drills, the HoDoKu cross-check) gets a smaller budget: a position can hold
        // tens of thousands of chains, and the first ones found are as good a drill as any.
        var budget = out.findAll ? alsChainBudget / 8 : alsChainBudget
        var path: [Int] = []
        var rccs: [Int] = []
        var onPath = [Bool](repeating: false, count: sets.count)
        var seenElims = Set<[Candidate]>()

        /// Whether sets A and Z, joined by a chain whose end links are x1 and xn, remove anything.
        func eliminates(_ A: ALSet, _ Z: ALSet, _ x1: Int, _ xn: Int) -> Bool {
            for z in Mask.digits(A.digits & Z.digits & ~Mask.bit(x1) & ~Mask.bit(xn)) {
                if !(A.seen[z] & Z.seen[z] - A.cells - Z.cells).isEmpty { return true }
            }
            return false
        }

        func dfs(_ cur: Int) -> Bool {
            let A = sets[path[0]], Z = sets[cur]
            if path.count >= 4 && eliminates(A, Z, rccs[0], rccs[rccs.count - 1]) {
                var elims: [Candidate] = []
                for z in Mask.digits(A.digits & Z.digits & ~Mask.bit(rccs[0]) & ~Mask.bit(rccs[rccs.count - 1])) {
                    elims += (A.seen[z] & Z.seen[z] - A.cells - Z.cells).map { Candidate($0, z) }
                }
                // Many chains remove the same candidates; one step each is enough.
                guard seenElims.insert(elims).inserted else { return true }
                let chain = path.map { sets[$0] }
                var text = chain[0].name
                for (i, x) in rccs.enumerated() { text += " -\(x)- " + chain[i + 1].name }
                out.add(Step(technique, eliminations: elims, highlights: alsHighlights(chain, b), complexity: path.count,
                             explanation: "ALS Chain: \(text). If the first set doesn't hold the common digit, each set in turn becomes locked along the chain, so the last one does: \(describeEliminations(elims))."))
                if out.done { return false }
            }
            if path.count == alsChainMaxLength { return true }
            let last = path.count == alsChainMaxLength - 1
            for (n, mask) in nbrs[cur] where !onPath[n] {
                for x in Mask.digits(mask) where rccs.last != x {
                    // The last set must be able to remove something with the first.
                    if last && !eliminates(A, sets[n], rccs.first ?? x, x) { continue }
                    budget -= 1
                    if budget <= 0 { return false }
                    path.append(n); rccs.append(x); onPath[n] = true
                    let cont = dfs(n)
                    path.removeLast(); rccs.removeLast(); onPath[n] = false
                    if !cont { return false }
                }
            }
            return true
        }

        for s in sets.indices {
            path = [s]; rccs = []; onPath[s] = true
            let cont = dfs(s)
            onPath[s] = false
            if !cont { return }
        }
    }
}

/// Sue de Coq, in HoDoKu's extended form. C: two or more empty cells of a box/line intersection,
/// holding the digits V with |V| >= |C| + 2. CL: cells of the line outside C (with candidates VL),
/// CB: cells of the box outside C (VB), disjoint, at least one each; either part may use the
/// spare intersection cell. No digit of V may be in both VL and VB. Every digit of V then fits at
/// most once in the whole pattern (only in the box part, only in the line part, or only in C), and
/// a digit outside V at most once in CL and once in CB. When that maximum equals the number of
/// cells, every digit is used to the full: V's digits outside VL are locked into the box, VB's
/// into the box, and likewise for the line.
struct SueDeCoq: Strategy {
    let technique = Technique.sueDeCoq
    /// The most cells in the line part or the box part.
    static let maxPart = 4

    func find(_ b: Board, _ out: inout StepCollector) {
        for box in 0..<9 {
            for line in 0..<18 {
                let inter = Geometry.houseSets[18 + box] & Geometry.houseSets[line]
                guard inter.count == 3 else { continue }
                let ic = inter.filter { b.isEmpty($0) }
                guard ic.count >= 2 else { continue }
                let lineOutside = Geometry.houses[line].filter { b.isEmpty($0) && !inter.contains($0) }
                let boxOutside = Geometry.houses[18 + box].filter { b.isEmpty($0) && !inter.contains($0) }
                for k in 2...ic.count {
                    forEachCombination(ic.count, k) { cidx in
                        let C = cidx.map { ic[$0] }
                        let V = b.union(C)
                        guard V.nonzeroBitCount >= k + 2 else { return true }
                        // A spare intersection cell may join either part.
                        let spare = ic.filter { !C.contains($0) }
                        let lineRest = spare + lineOutside
                        for lk in 1...max(1, min(Self.maxPart, lineRest.count)) where lk <= lineRest.count {
                            forEachCombination(lineRest.count, lk) { lidx in
                                let L = lidx.map { lineRest[$0] }
                                let lm = b.union(L)
                                guard lm & V != 0 else { return true }
                                let boxRest = spare.filter { !L.contains($0) } + boxOutside
                                for bk in 1...max(1, min(Self.maxPart, boxRest.count)) where bk <= boxRest.count {
                                    forEachCombination(boxRest.count, bk) { bidx in
                                        let B = bidx.map { boxRest[$0] }
                                        let bm = b.union(B)
                                        guard bm & lm & V == 0, bm & V != 0 else { return true }
                                        let capacity = V.nonzeroBitCount + (lm & ~V).nonzeroBitCount + (bm & ~V).nonzeroBitCount
                                        guard capacity == k + lk + bk else { return true }
                                        let used = Set(C + L + B)
                                        let lineKill = lm | (V & ~bm)
                                        let boxKill = bm | (V & ~lm)
                                        var elims: [Candidate] = []
                                        for c in Geometry.houses[line] where b.isEmpty(c) && !used.contains(c) {
                                            for d in Mask.digits(b.candidates[c] & lineKill) { elims.append(Candidate(c, d)) }
                                        }
                                        for c in Geometry.houses[18 + box] where b.isEmpty(c) && !used.contains(c) {
                                            // A spare intersection cell is in both houses.
                                            let kill = inter.contains(c) ? boxKill & ~lineKill : boxKill
                                            for d in Mask.digits(b.candidates[c] & kill) { elims.append(Candidate(c, d)) }
                                        }
                                        guard !elims.isEmpty else { return true }
                                        let shared = bm & lm
                                        let extra = shared == 0 ? "" : " (\(Mask.digits(shared).map(String.init).joined(separator: ", ")) can be in both parts, once in each)"
                                        out.add(Step(technique, eliminations: elims, houses: [line, 18 + box],
                                                     highlights: C.map { Highlight($0, 0, .pattern) } + L.map { Highlight($0, 0, .colorA) } + B.map { Highlight($0, 0, .colorB) },
                                                     explanation: "Sue de Coq: the intersection cells \(Geometry.cellsName(C)) with \(Geometry.cellsName(L)) in \(Geometry.houseName(line)) and \(Geometry.cellsName(B)) in \(Geometry.houseName(18 + box)) have just enough digits to fill their cells\(extra), so each digit is locked into the line or the box: \(describeEliminations(elims))."))
                                        return !out.done
                                    }
                                    if out.done { return false }
                                }
                                return !out.done
                            }
                            if out.done { return false }
                        }
                        return !out.done
                    }
                    if out.done { return }
                }
            }
        }
    }
}
