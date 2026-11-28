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

/// The digit pairs {u, v} a rectangle can be a unique rectangle on. Normally every corner must
/// hold both. With `missing`, a corner may lack one of them as long as no given rules it out
/// there (HoDoKu's "missing candidates"): the four cells are empty, so swapping u and v in a
/// solution where they held only u and v would still give a second solution. Only pairs where
/// some corner really lacks a digit are returned then, and every corner keeps at least one.
func rectanglePairs(_ b: Board, _ rect: [Int], missing: Bool) -> [(Int, Int)] {
    var out: [(Int, Int)] = []
    if !missing {
        let common = Mask.digits(rect.reduce(Mask.all) { $0 & b.candidates[$1] })
        for i in 0..<common.count { for j in (i + 1)..<common.count { out.append((common[i], common[j])) } }
        return out
    }
    let union = Mask.digits(rect.reduce(DigitMask(0)) { $0 | b.candidates[$1] })
    for i in 0..<union.count {
        for j in (i + 1)..<union.count {
            let ab = Mask.bit(union[i]) | Mask.bit(union[j])
            guard rect.allSatisfy({ b.candidates[$0] & ab != 0 }),
                  rect.contains(where: { b.candidates[$0] & ab != ab }),
                  !missingCandidates(b, rect, ab).contains(where: { blockedByGiven(b, $0.cell, $0.digit) }) else { continue }
            out.append((union[i], union[j]))
        }
    }
    return out
}

/// The rectangle digits (from `ab`) that corners of `rect` no longer hold.
func missingCandidates(_ b: Board, _ rect: [Int], _ ab: DigitMask) -> [Candidate] {
    rect.flatMap { c in Mask.digits(ab & ~b.candidates[c]).map { Candidate(c, $0) } }
}

private func blockedByGiven(_ b: Board, _ cell: Int, _ d: Int) -> Bool {
    Geometry.peers[cell].contains { b.givens.contains($0) && b.value($0) == d }
}

/// Whether `d` is still open in house `h` and every candidate `d` there lies in `cells`. A digit
/// already placed in the house has no candidates left, which is not "confined to the rectangle".
private func confined(_ b: Board, _ d: Int, _ h: Int, to cells: [Int]) -> Bool {
    b.positionMask(d, h) != 0 && Geometry.houses[h].allSatisfy { !b.has($0, d) || cells.contains($0) }
}

/// The rectangle's digits as pattern highlights, on the corners that still hold them.
private func rectangleHighlights(_ b: Board, _ rect: [Int], _ u: Int, _ v: Int) -> [Highlight] {
    rect.flatMap { c in [u, v].filter { b.has(c, $0) }.map { Highlight(c, $0, .pattern) } }
}

/// The sentence a missing-candidate step adds: which corners lost which digit, and why the
/// rectangle still counts.
func missingNote(_ b: Board, _ rect: [Int], _ u: Int, _ v: Int) -> String {
    let gone = missingCandidates(b, rect, Mask.bit(u) | Mask.bit(v))
    guard !gone.isEmpty else { return "" }
    let parts = gone.map { "\(Geometry.cellName($0.cell)) has lost its \($0.digit)" }
    let list = parts.count == 1 ? parts[0] : parts.dropLast().joined(separator: ", ") + " and " + parts.last!
    let it = gone.count == 1 ? "it was removed by an earlier step, not ruled out by a given" : "they were removed by earlier steps, not ruled out by givens"
    return " The rectangle still counts although \(list): \(it), so if all four corners ended up \(u) and \(v), swapping \(u) and \(v) would still give a second solution."
}

struct UniqueRectangle: Strategy {
    let type: Int
    /// Allow corners that lack a rectangle digit (`Technique.uniqueRectangleMissing`).
    var missing = false
    var technique: Technique {
        missing ? .uniqueRectangleMissing
            : [1: .uniqueRectangle1, 2: .uniqueRectangle2, 3: .uniqueRectangle3, 4: .uniqueRectangle4, 5: .uniqueRectangle5, 6: .uniqueRectangle6][type]!
    }

    func find(_ b: Board, _ out: inout StepCollector) {
        let title = missing ? "Unique Rectangle Type \(type) with a missing candidate" : type == 1 ? "Unique Rectangle" : "Unique Rectangle Type \(type)"
        for rect in rectangles(b) {
            for (u, v) in rectanglePairs(b, rect, missing: missing) {
                    let ab = Mask.bit(u) | Mask.bit(v)
                    let floor = rect.filter { b.candidates[$0] & ~ab == 0 }
                    let roof = rect.filter { b.candidates[$0] & ~ab != 0 }
                    let name = "{\(u)\(v)} rectangle \(Geometry.cellsName(rect))"
                    let hl = rectangleHighlights(b, rect, u, v)
                    let note = missing ? missingNote(b, rect, u, v) : ""
                    switch type {
                    case 1:
                        guard roof.count == 1 else { continue }
                        let r = roof[0]
                        let elims = [u, v].filter { b.has(r, $0) }.map { Candidate(r, $0) }
                        guard !elims.isEmpty else { continue }
                        let corners = missing ? "the other three corners of \(name) hold nothing but \(u) and \(v)" : "three corners of \(name) hold only \(u) and \(v)"
                        out.add(Step(technique, eliminations: elims, highlights: hl,
                                     explanation: "\(title): \(corners). If \(Geometry.cellName(r)) were also \(u) or \(v), the puzzle would have two solutions, so \(describeEliminations(elims)).\(note)"))
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
                                         explanation: "\(title): in \(name), the roof cells \(Geometry.cellsName(roof)) both have the extra candidate \(x). To avoid two solutions one of them must be \(x): \(describeEliminations(elims)).\(note)"))
                        } else if type == 4 {
                            for h in shared {
                                for (lock, kill) in [(u, v), (v, u)] {
                                    guard confined(b, lock, h, to: roof) else { continue }
                                    let elims = roof.filter { b.has($0, kill) }.map { Candidate($0, kill) }
                                    guard !elims.isEmpty else { continue }
                                    out.add(Step(technique, eliminations: elims, houses: [h], highlights: hl,
                                                 explanation: "\(title): in \(name), \(lock) must be in one of the roof cells \(Geometry.cellsName(roof)) (it has nowhere else in \(Geometry.houseName(h))). The other roof cell then can't be \(kill) without a deadly pattern: \(describeEliminations(elims)).\(note)"))
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
                                                     explanation: "\(title): in \(name), one roof cell must hold an extra digit (\(Mask.digits(extra).map(String.init).joined(separator: "/"))). Together with \(Geometry.cellsName(set)) they form a locked set in \(Geometry.houseName(h)): \(describeEliminations(elims)).\(note)"))
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
                                     explanation: "\(title): in \(name), the corners \(Geometry.cellsName(roof)) all carry the extra candidate \(x). One of them must be \(x) to avoid two solutions: \(describeEliminations(elims)).\(note)"))
                    case 6:
                        guard roof.count == 2, floor.count == 2, Geometry.sharedHouses(floor).isEmpty else { continue }
                        let rows = Array(Set(rect.map { Geometry.rowOf[$0] })), cols = Array(Set(rect.map { 9 + Geometry.colOf[$0] }))
                        for (x, other) in [(u, v), (v, u)] {
                            let inRows = rows.allSatisfy { confined(b, x, $0, to: rect) }
                            let inCols = cols.allSatisfy { confined(b, x, $0, to: rect) }
                            guard inRows || inCols else { continue }
                            let elims = roof.filter { b.has($0, x) }.map { Candidate($0, x) }
                            guard !elims.isEmpty else { continue }
                            out.add(Step(technique, eliminations: elims, houses: inRows ? rows : cols, highlights: hl,
                                         explanation: "\(title): in \(name), \(x) forms an X-Wing on the rectangle, so it sits on one diagonal. On the diagonal \(Geometry.cellsName(roof)) the other two corners would both be \(other), a deadly pattern: \(describeEliminations(elims)).\(note)"))
                            if out.done { return }
                        }
                    default: break
                    }
                    if out.done { return }
            }
        }
    }
}

struct HiddenRectangle: Strategy {
    /// Allow corners that lack a rectangle digit (`Technique.uniqueRectangleMissing`).
    var missing = false
    var technique: Technique { missing ? .uniqueRectangleMissing : .hiddenRectangle }
    func find(_ b: Board, _ out: inout StepCollector) {
        let title = missing ? "Hidden Rectangle with a missing candidate" : "Hidden Rectangle"
        for rect in rectangles(b) {
            for (p, q) in rectanglePairs(b, rect, missing: missing) {
                    let ab = Mask.bit(p) | Mask.bit(q)
                    for a in rect where b.candidates[a] == ab {
                        // D is the corner diagonal from A.
                        guard let d = rect.first(where: { Geometry.rowOf[$0] != Geometry.rowOf[a] && Geometry.colOf[$0] != Geometry.colOf[a] }) else { continue }
                        let rowD = Geometry.rowOf[d], colD = 9 + Geometry.colOf[d]
                        for (u, v) in [(p, q), (q, p)] {
                            guard b.has(d, v), confined(b, u, rowD, to: rect), confined(b, u, colD, to: rect) else { continue }
                            let elims = [Candidate(d, v)]
                            let note = missing ? missingNote(b, rect, p, q) : ""
                            out.add(Step(technique, eliminations: elims, houses: [rowD, colD],
                                         highlights: rectangleHighlights(b, rect, p, q),
                                         explanation: "\(title): \(Geometry.cellName(a)) is {\(p)\(q)} and \(u) is confined to the rectangle in both row \(rowD + 1) and column \(colD - 8). If \(Geometry.cellName(d)) were \(v), the rectangle would be a deadly pattern: \(describeEliminations(elims)).\(note)"))
                            if out.done { return }
                        }
                    }
            }
        }
    }
}

/// Unique rectangles and hidden rectangles whose corners have lost a rectangle digit to an
/// earlier step (HoDoKu's "missing candidates"). One technique for every type: the new idea is
/// the same each time (a digit that's gone from a corner still counts for the deadly pattern),
/// and the type mechanics are taught by the ordinary rectangles.
struct UniqueRectangleMissing: Strategy {
    let technique = Technique.uniqueRectangleMissing
    func find(_ b: Board, _ out: inout StepCollector) {
        for type in 1...6 {
            UniqueRectangle(type: type, missing: true).find(b, &out)
            if out.done { return }
        }
        HiddenRectangle(missing: true).find(b, &out)
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
