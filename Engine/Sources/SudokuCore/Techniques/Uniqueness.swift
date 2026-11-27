/// Rectangles spanning exactly two boxes whose four corners are all empty.
func rectangles(_ b: Board) -> [[Int]] {
    allRectangles.filter { b.isEmpty($0[0]) && b.isEmpty($0[1]) && b.isEmpty($0[2]) && b.isEmpty($0[3]) }
}

/// Every rectangle spanning exactly two boxes, as its four cells.
private let allRectangles: [[Int]] = {
    var out: [[Int]] = []
    for r1 in 0..<8 {
        for r2 in (r1 + 1)..<9 {
            for c1 in 0..<8 {
                for c2 in (c1 + 1)..<9 {
                    let sameBand = r1 / 3 == r2 / 3, sameStack = c1 / 3 == c2 / 3
                    guard sameBand != sameStack else { continue }
                    out.append([r1 * 9 + c1, r1 * 9 + c2, r2 * 9 + c1, r2 * 9 + c2])
                }
            }
        }
    }
    return out
}()

struct UniqueRectangle: Strategy {
    let type: Int
    var technique: Technique { [1: .uniqueRectangle1, 2: .uniqueRectangle2, 3: .uniqueRectangle3, 4: .uniqueRectangle4, 5: .uniqueRectangle5, 6: .uniqueRectangle6][type]! }

    func find(_ b: Board, _ out: inout StepCollector) {
        for rect in rectangles(b) {
            let common = rect.reduce(Mask.all) { $0 & b.candidates[$1] }
            guard common.nonzeroBitCount >= 2 else { continue }
            let pairs = Mask.digits(common)
            for i in 0..<pairs.count {
                for j in (i + 1)..<pairs.count {
                    let (u, v) = (pairs[i], pairs[j])
                    let ab = Mask.bit(u) | Mask.bit(v)
                    let floor = rect.filter { b.candidates[$0] == ab }
                    let roof = rect.filter { b.candidates[$0] != ab }
                    let name = "{\(u)\(v)} rectangle \(Geometry.cellsName(rect))"
                    let hl = rect.flatMap { [Highlight($0, u, .pattern), Highlight($0, v, .pattern)] }
                    switch type {
                    case 1:
                        guard roof.count == 1 else { continue }
                        let r = roof[0]
                        let elims = [Candidate(r, u), Candidate(r, v)]
                        out.add(Step(technique, eliminations: elims, highlights: hl,
                                     explanation: "Unique Rectangle: three corners of \(name) hold only \(u) and \(v). If \(Geometry.cellName(r)) were also \(u) or \(v), the puzzle would have two solutions, so \(describeEliminations(elims))."))
                    case 2, 3, 4:
                        guard roof.count == 2, floor.count == 2 else { continue }
                        let shared = Geometry.sharedHouses(roof)
                        guard !shared.isEmpty else { continue }
                        let e1 = b.candidates[roof[0]] & ~ab, e2 = b.candidates[roof[1]] & ~ab
                        if type == 2 {
                            guard e1 == e2, e1.nonzeroBitCount == 1 else { continue }
                            let x = Mask.first(e1)
                            let elims = b.filter(Geometry.commonPeers(CellSet(roof)), x).map { Candidate($0, x) }
                            guard !elims.isEmpty else { continue }
                            out.add(Step(technique, eliminations: elims, houses: shared, highlights: hl + roof.map { Highlight($0, x, .secondary) },
                                         explanation: "Unique Rectangle Type 2: in \(name), the roof cells \(Geometry.cellsName(roof)) both have the extra candidate \(x). To avoid two solutions one of them must be \(x): \(describeEliminations(elims))."))
                        } else if type == 4 {
                            for h in shared {
                                for (lock, kill) in [(u, v), (v, u)] {
                                    guard b.positionMask(lock, h).nonzeroBitCount == 2 else { continue }
                                    let elims = roof.map { Candidate($0, kill) }
                                    out.add(Step(technique, eliminations: elims, houses: [h], highlights: hl,
                                                 explanation: "Unique Rectangle Type 4: in \(name), \(lock) must be in one of the roof cells \(Geometry.cellsName(roof)) (it has nowhere else in \(Geometry.houseName(h))). The other roof cell then can't be \(kill) without a deadly pattern: \(describeEliminations(elims))."))
                                    if out.done { return }
                                }
                            }
                        } else {
                            // Type 3: roof extras act as a virtual cell in a naked subset.
                            let extra = e1 | e2
                            guard extra.nonzeroBitCount >= 2 else { continue }
                            for h in shared {
                                let others = Geometry.houses[h].filter { b.isEmpty($0) && !roof.contains($0) }
                                for k in 1...3 {
                                    forEachCombination(others.count, k) { idx in
                                        let set = idx.map { others[$0] }
                                        let u2 = b.union(set) | extra
                                        guard u2.nonzeroBitCount == k + 1 else { return true }
                                        var elims: [Candidate] = []
                                        for c in others where !set.contains(c) {
                                            for d in Mask.digits(b.candidates[c] & u2) { elims.append(Candidate(c, d)) }
                                        }
                                        guard !elims.isEmpty else { return true }
                                        out.add(Step(technique, eliminations: elims, houses: [h], highlights: hl + set.map { Highlight($0, 0, .secondary) },
                                                     explanation: "Unique Rectangle Type 3: in \(name), one roof cell must hold an extra digit (\(Mask.digits(extra).map(String.init).joined(separator: "/"))). Together with \(Geometry.cellsName(set)) they form a locked set in \(Geometry.houseName(h)): \(describeEliminations(elims))."))
                                        return !out.done
                                    }
                                    if out.done { return }
                                }
                            }
                        }
                    case 5:
                        guard roof.count == 2 || roof.count == 3 else { continue }
                        let extras = roof.map { b.candidates[$0] & ~ab }
                        guard extras.allSatisfy({ $0 == extras[0] }), extras[0].nonzeroBitCount == 1 else { continue }
                        // Adjacent pair is Type 2.
                        if roof.count == 2 && !Geometry.sharedHouses(roof).isEmpty { continue }
                        let x = Mask.first(extras[0])
                        let elims = b.filter(Geometry.commonPeers(CellSet(roof)), x).map { Candidate($0, x) }
                        guard !elims.isEmpty else { continue }
                        out.add(Step(technique, eliminations: elims, highlights: hl + roof.map { Highlight($0, x, .secondary) },
                                     explanation: "Unique Rectangle Type 5: in \(name), the corners \(Geometry.cellsName(roof)) all carry the extra candidate \(x). One of them must be \(x) to avoid two solutions: \(describeEliminations(elims))."))
                    case 6:
                        guard roof.count == 2, floor.count == 2, Geometry.sharedHouses(floor).isEmpty else { continue }
                        let rows = Array(Set(rect.map { Geometry.rowOf[$0] })), cols = Array(Set(rect.map { 9 + Geometry.colOf[$0] }))
                        for (x, other) in [(u, v), (v, u)] {
                            let inRows = rows.allSatisfy { b.positionMask(x, $0).nonzeroBitCount == 2 }
                            let inCols = cols.allSatisfy { b.positionMask(x, $0).nonzeroBitCount == 2 }
                            guard inRows || inCols else { continue }
                            let elims = roof.map { Candidate($0, x) }
                            out.add(Step(technique, eliminations: elims, houses: inRows ? rows : cols, highlights: hl,
                                         explanation: "Unique Rectangle Type 6: in \(name), \(x) forms an X-Wing on the rectangle, so it sits on one diagonal. On the diagonal \(Geometry.cellsName(roof)) the other two corners would both be \(other), a deadly pattern: \(describeEliminations(elims))."))
                            if out.done { return }
                        }
                    default: break
                    }
                    if out.done { return }
                }
            }
        }
    }
}

struct HiddenRectangle: Strategy {
    let technique = Technique.hiddenRectangle
    func find(_ b: Board, _ out: inout StepCollector) {
        for rect in rectangles(b) {
            let common = rect.reduce(Mask.all) { $0 & b.candidates[$1] }
            guard common.nonzeroBitCount >= 2 else { continue }
            let pairs = Mask.digits(common)
            for i in 0..<pairs.count {
                for j in (i + 1)..<pairs.count {
                    let ab = Mask.bit(pairs[i]) | Mask.bit(pairs[j])
                    for a in rect where b.candidates[a] == ab {
                        // D is the corner diagonal from A.
                        guard let d = rect.first(where: { Geometry.rowOf[$0] != Geometry.rowOf[a] && Geometry.colOf[$0] != Geometry.colOf[a] }) else { continue }
                        let rowD = Geometry.rowOf[d], colD = 9 + Geometry.colOf[d]
                        for (u, v) in [(pairs[i], pairs[j]), (pairs[j], pairs[i])] {
                            guard b.positionMask(u, rowD).nonzeroBitCount == 2, b.positionMask(u, colD).nonzeroBitCount == 2 else { continue }
                            let elims = [Candidate(d, v)]
                            out.add(Step(technique, eliminations: elims, houses: [rowD, colD],
                                         highlights: rect.flatMap { [Highlight($0, pairs[i], .pattern), Highlight($0, pairs[j], .pattern)] },
                                         explanation: "Hidden Rectangle: \(Geometry.cellName(a)) is {\(pairs[i])\(pairs[j])} and \(u) is confined to the rectangle in both row \(rowD + 1) and column \(colD - 8). If \(Geometry.cellName(d)) were \(v), the rectangle would be a deadly pattern: \(describeEliminations(elims))."))
                            if out.done { return }
                        }
                    }
                }
            }
        }
    }
}

struct BUGPlusOne: Strategy {
    let technique = Technique.bugPlusOne
    func find(_ b: Board, _ out: inout StepCollector) {
        var tri = -1
        for c in 0..<81 where b.isEmpty(c) {
            let n = b.candidates[c].nonzeroBitCount
            if n == 2 { continue }
            if n == 3 && tri < 0 { tri = c; continue }
            return
        }
        guard tri >= 0 else { return }
        for d in Mask.digits(b.candidates[tri]) {
            if Geometry.housesOfCell[tri].contains(where: { b.positionMask(d, $0).nonzeroBitCount == 3 }) {
                out.add(Step(technique, placements: [Candidate(tri, d)], houses: Geometry.housesOfCell[tri],
                             highlights: [Highlight(tri, d, .pattern)],
                             explanation: "BUG+1: every empty cell except \(Geometry.cellName(tri)) has exactly two candidates. Without \(d) there, the puzzle would have two solutions, so \(Geometry.cellName(tri)) is \(d)."))
                return
            }
        }
    }
}

/// Avoidable Rectangle Type 1: three corners solved (not given) in a deadly-pattern shape.
struct AvoidableRectangle: Strategy {
    let technique = Technique.avoidableRectangle
    func find(_ b: Board, _ out: inout StepCollector) {
        for r1 in 0..<8 {
            for r2 in (r1 + 1)..<9 {
                for c1 in 0..<8 {
                    for c2 in (c1 + 1)..<9 {
                        guard (r1 / 3 == r2 / 3) != (c1 / 3 == c2 / 3) else { continue }
                        let rect = [r1 * 9 + c1, r1 * 9 + c2, r2 * 9 + c1, r2 * 9 + c2]
                        guard !rect.contains(where: { b.givens.contains($0) }) else { continue }
                        let empty = rect.filter { b.isEmpty($0) }
                        guard empty.count == 1 else { continue }
                        let e = empty[0]
                        let diag = rect.first { Geometry.rowOf[$0] != Geometry.rowOf[e] && Geometry.colOf[$0] != Geometry.colOf[e] }!
                        let sides = rect.filter { $0 != e && $0 != diag }
                        let a = b.value(diag), x = b.value(sides[0])
                        guard x == b.value(sides[1]), a != x, b.has(e, a) else { continue }
                        let elims = [Candidate(e, a)]
                        out.add(Step(technique, eliminations: elims,
                                     highlights: rect.filter { $0 != e }.map { Highlight($0, 0, .pattern) },
                                     explanation: "Avoidable Rectangle: \(Geometry.cellsName(rect.filter { $0 != e })) were solved (not given) as \(a)/\(x). If \(Geometry.cellName(e)) were \(a), swapping \(a) and \(x) in all four cells would give a second solution: \(describeEliminations(elims))."))
                        if out.done { return }
                    }
                }
            }
        }
    }
}

/// Avoidable Rectangle Type 2: two corners on one side are solved (not given) as a and b. The
/// other two corners hold {b, x} and {a, x}, diagonal to the matching solved digit. If neither
/// took x, a/b would fill the rectangle in a swappable way, so one of them is x.
struct AvoidableRectangle2: Strategy {
    let technique = Technique.avoidableRectangle2
    func find(_ b: Board, _ out: inout StepCollector) {
        for r1 in 0..<8 {
            for r2 in (r1 + 1)..<9 {
                for c1 in 0..<8 {
                    for c2 in (c1 + 1)..<9 {
                        guard (r1 / 3 == r2 / 3) != (c1 / 3 == c2 / 3) else { continue }
                        let tl = r1 * 9 + c1, tr = r1 * 9 + c2, bl = r2 * 9 + c1, br = r2 * 9 + c2
                        // The solved side and the open side, as (solved1, solved2, open below 1, open below 2).
                        for (s1, s2, o1, o2) in [(tl, tr, bl, br), (bl, br, tl, tr), (tl, bl, tr, br), (tr, br, tl, bl)] {
                            guard !b.isEmpty(s1), !b.isEmpty(s2), !b.givens.contains(s1), !b.givens.contains(s2),
                                  b.isEmpty(o1), b.isEmpty(o2) else { continue }
                            let a = b.value(s1), bb = b.value(s2)
                            guard a != bb else { continue }
                            // o1 is next to s1, so it would take bb; o2 would take a.
                            let m1 = b.candidates[o1], m2 = b.candidates[o2]
                            guard m1.nonzeroBitCount == 2, m2.nonzeroBitCount == 2,
                                  m1 & Mask.bit(bb) != 0, m2 & Mask.bit(a) != 0 else { continue }
                            let x1 = m1 & ~Mask.bit(bb), x2 = m2 & ~Mask.bit(a)
                            guard x1 == x2, x1 & (Mask.bit(a) | Mask.bit(bb)) == 0 else { continue }
                            let x = Mask.first(x1)
                            let targets = Geometry.commonPeers(CellSet([o1, o2]))
                            let elims = b.filter(targets, x).map { Candidate($0, x) }
                            guard !elims.isEmpty else { continue }
                            out.add(Step(technique, eliminations: elims,
                                         highlights: [Highlight(s1, 0, .pattern), Highlight(s2, 0, .pattern),
                                                      Highlight(o1, bb, .pattern), Highlight(o2, a, .pattern),
                                                      Highlight(o1, x, .fin), Highlight(o2, x, .fin)],
                                         explanation: "Avoidable Rectangle Type 2: \(Geometry.cellName(s1)) and \(Geometry.cellName(s2)) were solved (not given) as \(a) and \(bb). If \(Geometry.cellName(o1)) were \(bb) and \(Geometry.cellName(o2)) were \(a), swapping \(a) and \(bb) in all four cells would give a second solution. So one of them is \(x): \(describeEliminations(elims))."))
                            if out.done { return }
                        }
                    }
                }
            }
        }
    }
}
