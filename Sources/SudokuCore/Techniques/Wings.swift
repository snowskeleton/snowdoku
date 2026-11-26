struct XYWing: Strategy {
    let technique = Technique.xyWing
    func find(_ b: Board, _ out: inout StepCollector) {
        let bivalue = (0..<81).filter { b.candidates[$0].nonzeroBitCount == 2 }
        for p in bivalue {
            let pm = b.candidates[p]
            let wings = Geometry.peers[p].filter { b.candidates[$0].nonzeroBitCount == 2 && (b.candidates[$0] & pm).nonzeroBitCount == 1 }
            for i in 0..<wings.count {
                for j in (i + 1)..<max(i + 1, wings.count) {
                    let a = wings[i], c = wings[j]
                    let am = b.candidates[a], cm = b.candidates[c]
                    // a = xz, c = yz with x != y
                    guard (am & pm) != (cm & pm) else { continue }
                    let z = am & cm & ~pm
                    guard z.nonzeroBitCount == 1 else { continue }
                    let zd = Mask.first(z)
                    let elims = b.filter(Geometry.commonPeers(CellSet([a, c])) - CellSet([p]), zd).map { Candidate($0, zd) }
                    guard !elims.isEmpty else { continue }
                    out.add(Step(technique, eliminations: elims, houses: [],
                                 highlights: [Highlight(p, 0, .pattern), Highlight(a, zd, .secondary), Highlight(c, zd, .secondary)],
                                 explanation: "XY-Wing: pivot \(Geometry.cellName(p)) {\(Mask.digits(pm).map(String.init).joined())} sees \(Geometry.cellName(a)) {\(Mask.digits(am).map(String.init).joined())} and \(Geometry.cellName(c)) {\(Mask.digits(cm).map(String.init).joined())}. Whatever the pivot is, one wing becomes \(zd): \(describeEliminations(elims))."))
                    if out.done { return }
                }
            }
        }
    }
}

struct XYZWing: Strategy {
    let technique = Technique.xyzWing
    func find(_ b: Board, _ out: inout StepCollector) {
        for p in 0..<81 where b.candidates[p].nonzeroBitCount == 3 {
            let pm = b.candidates[p]
            let wings = Geometry.peers[p].filter { b.candidates[$0].nonzeroBitCount == 2 && b.candidates[$0] & ~pm == 0 }
            for i in 0..<wings.count {
                for j in (i + 1)..<max(i + 1, wings.count) {
                    let a = wings[i], c = wings[j]
                    let am = b.candidates[a], cm = b.candidates[c]
                    guard am | cm == pm, (am & cm).nonzeroBitCount == 1 else { continue }
                    let zd = Mask.first(am & cm)
                    let elims = b.filter(Geometry.commonPeers(CellSet([p, a, c])), zd).map { Candidate($0, zd) }
                    guard !elims.isEmpty else { continue }
                    out.add(Step(technique, eliminations: elims,
                                 highlights: [Highlight(p, 0, .pattern), Highlight(a, zd, .secondary), Highlight(c, zd, .secondary), Highlight(p, zd, .secondary)],
                                 explanation: "XYZ-Wing: pivot \(Geometry.cellName(p)) with wings \(Geometry.cellName(a)) and \(Geometry.cellName(c)). One of the three must be \(zd): \(describeEliminations(elims))."))
                    if out.done { return }
                }
            }
        }
    }
}

struct WWing: Strategy {
    let technique = Technique.wWing
    func find(_ b: Board, _ out: inout StepCollector) {
        let bivalue = (0..<81).filter { b.candidates[$0].nonzeroBitCount == 2 }
        var linksByDigit: [[StrongLink]] = Array(repeating: [], count: 10)
        for d in 1...9 { linksByDigit[d] = strongLinks(b, d) }
        for i in 0..<bivalue.count {
            for j in (i + 1)..<max(i + 1, bivalue.count) {
                let x = bivalue[i], y = bivalue[j]
                guard b.candidates[x] == b.candidates[y], !Geometry.sees(x, y) else { continue }
                let ds = Mask.digits(b.candidates[x])
                for (s, o) in [(ds[0], ds[1]), (ds[1], ds[0])] {
                    for l in linksByDigit[s] {
                        for (e1, e2) in [(l.a, l.b), (l.b, l.a)] {
                            guard e1 != x, e1 != y, e2 != x, e2 != y,
                                  Geometry.sees(x, e1), Geometry.sees(y, e2) else { continue }
                            let elims = b.filter(Geometry.commonPeers(CellSet([x, y])), o).map { Candidate($0, o) }
                            guard !elims.isEmpty else { continue }
                            out.add(Step(technique, eliminations: elims, houses: [l.house],
                                         highlights: [Highlight(x, 0, .pattern), Highlight(y, 0, .pattern), Highlight(e1, s, .secondary), Highlight(e2, s, .secondary)],
                                         explanation: "W-Wing: \(Geometry.cellName(x)) and \(Geometry.cellName(y)) are both {\(s)\(o)}, joined by the strong link on \(s) between \(Geometry.cellName(e1)) and \(Geometry.cellName(e2)). They can't both be \(s), so one is \(o): \(describeEliminations(elims))."))
                            if out.done { return }
                        }
                    }
                }
            }
        }
    }
}

/// Bent sets of four cells holding four digits with exactly one non-restricted digit.
struct WXYZWing: Strategy {
    let technique = Technique.wxyzWing
    func find(_ b: Board, _ out: inout StepCollector) {
        var seen = Set<CellSet>()
        for p in 0..<81 where b.isEmpty(p) && b.candidates[p].nonzeroBitCount <= 4 {
            let pool = Geometry.peers[p].filter { b.isEmpty($0) && (2...4).contains(b.candidates[$0].nonzeroBitCount) }
            forEachCombination(pool.count, 3) { idx in
                let cells = [p] + idx.map { pool[$0] }
                let u = b.union(cells)
                guard u.nonzeroBitCount == 4 else { return true }
                let set = CellSet(cells)
                guard seen.insert(set).inserted else { return true }
                var nonRestricted: [Int] = []
                for d in Mask.digits(u) {
                    let dc = cells.filter { b.has($0, d) }
                    var ok = true
                    for i in 0..<dc.count { for j in (i + 1)..<max(i + 1, dc.count) where !Geometry.sees(dc[i], dc[j]) { ok = false } }
                    if !ok { nonRestricted.append(d) }
                }
                guard nonRestricted.count == 1 else { return true }
                let z = nonRestricted[0]
                let zc = CellSet(cells.filter { b.has($0, z) })
                let elims = b.filter(Geometry.commonPeers(zc) - set, z).map { Candidate($0, z) }
                guard !elims.isEmpty else { return true }
                out.add(Step(technique, eliminations: elims,
                             highlights: cells.map { Highlight($0, 0, .pattern) } + zc.map { Highlight($0, z, .secondary) },
                             explanation: "WXYZ-Wing: \(Geometry.cellsName(cells)) hold exactly four digits and only \(z) can repeat among them, so one of them must be \(z): \(describeEliminations(elims))."))
                return !out.done
            }
            if out.done { return }
        }
    }
}
