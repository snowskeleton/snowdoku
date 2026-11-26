/// An Almost Locked Set: N cells in one house holding exactly N+1 candidates.
struct ALSet {
    let cells: CellSet
    let list: [Int]
    let digits: DigitMask
    let byDigit: [CellSet]   // index 1...9
    let house: Int

    var name: String { "\(Geometry.cellsName(list)) {\(Mask.digits(digits).map(String.init).joined())}" }
}

func findALS(_ b: Board, maxSize: Int = 6) -> [ALSet] {
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
                for d in Mask.digits(u) { by[d] = CellSet(cells.filter { b.has($0, d) }) }
                result.append(ALSet(cells: set, list: cells, digits: u, byDigit: by, house: h))
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

struct ALSXYWing: Strategy {
    let technique = Technique.alsXYWing
    func find(_ b: Board, _ out: inout StepCollector) {
        let sets = findALS(b, maxSize: 5)
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
        let sets = findALS(b, maxSize: 5)
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

struct SueDeCoq: Strategy {
    let technique = Technique.sueDeCoq
    func find(_ b: Board, _ out: inout StepCollector) {
        for box in 0..<9 {
            for line in 0..<18 {
                let inter = Geometry.houseSets[18 + box] & Geometry.houseSets[line]
                guard inter.count == 3 else { continue }
                let ic = inter.filter { b.isEmpty($0) }
                guard ic.count >= 2 else { continue }
                let lineRest = Geometry.houses[line].filter { b.isEmpty($0) && !inter.contains($0) }
                let boxRest = Geometry.houses[18 + box].filter { b.isEmpty($0) && !inter.contains($0) }
                for k in 2...ic.count {
                    forEachCombination(ic.count, k) { cidx in
                        let C = cidx.map { ic[$0] }
                        let V = b.union(C)
                        guard V.nonzeroBitCount >= k + 2 else { return true }
                        for lk in 1...min(3, lineRest.count) {
                            forEachCombination(lineRest.count, lk) { lidx in
                                let L = lidx.map { lineRest[$0] }
                                let lm = b.union(L)
                                // Line cells must share digits with the intersection to be useful.
                                guard lm & V != 0 else { return true }
                                for bk in 1...min(3, max(1, boxRest.count)) where bk <= boxRest.count {
                                    forEachCombination(boxRest.count, bk) { bidx in
                                        let B = bidx.map { boxRest[$0] }
                                        let bm = b.union(B)
                                        guard bm & lm == 0, bm & V != 0 else { return true }
                                        let D = V | lm | bm
                                        guard D.nonzeroBitCount == k + lk + bk else { return true }
                                        let lineKill = lm | (V & ~bm)
                                        let boxKill = bm | (V & ~lm)
                                        var elims: [Candidate] = []
                                        for c in lineRest where !L.contains(c) {
                                            for d in Mask.digits(b.candidates[c] & lineKill) { elims.append(Candidate(c, d)) }
                                        }
                                        for c in boxRest where !B.contains(c) {
                                            for d in Mask.digits(b.candidates[c] & boxKill) { elims.append(Candidate(c, d)) }
                                        }
                                        guard !elims.isEmpty else { return true }
                                        out.add(Step(technique, eliminations: elims, houses: [line, 18 + box],
                                                     highlights: C.map { Highlight($0, 0, .pattern) } + L.map { Highlight($0, 0, .colorA) } + B.map { Highlight($0, 0, .colorB) },
                                                     explanation: "Sue de Coq: the intersection cells \(Geometry.cellsName(C)) with \(Geometry.cellsName(L)) in \(Geometry.houseName(line)) and \(Geometry.cellsName(B)) in \(Geometry.houseName(18 + box)) hold exactly as many digits as cells, so each digit is locked into the line or the box: \(describeEliminations(elims))."))
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
