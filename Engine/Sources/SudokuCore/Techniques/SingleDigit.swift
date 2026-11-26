struct StrongLink { let a: Int, b: Int, house: Int }

func strongLinks(_ b: Board, _ d: Int) -> [StrongLink] {
    (0..<27).compactMap { h in
        let p = b.positions(d, h)
        return p.count == 2 ? StrongLink(a: p[0], b: p[1], house: h) : nil
    }
}

/// Skyscraper, 2-String Kite and Turbot Fish: strong - weak - strong on one digit.
struct TurbotFamily: Strategy {
    enum Kind: Sendable { case skyscraper, twoStringKite, turbotFish }
    let kind: Kind
    var technique: Technique {
        switch kind {
        case .skyscraper: .skyscraper
        case .twoStringKite: .twoStringKite
        case .turbotFish: .turbotFish
        }
    }

    func classify(_ l1: StrongLink, _ l2: StrongLink, _ a2: Int, _ b1: Int) -> Kind {
        let k1 = Geometry.kind(l1.house), k2 = Geometry.kind(l2.house)
        if k1 == .row && k2 == .row && Geometry.colOf[a2] == Geometry.colOf[b1] { return .skyscraper }
        if k1 == .column && k2 == .column && Geometry.rowOf[a2] == Geometry.rowOf[b1] { return .skyscraper }
        if ((k1 == .row && k2 == .column) || (k1 == .column && k2 == .row)) && Geometry.boxOf[a2] == Geometry.boxOf[b1] { return .twoStringKite }
        return .turbotFish
    }

    func find(_ b: Board, _ out: inout StepCollector) {
        for d in 1...9 {
            let links = strongLinks(b, d)
            guard links.count >= 2 else { continue }
            for i in 0..<links.count {
                for j in 0..<links.count where j != i {
                    let l1 = links[i], l2 = links[j]
                    for (a1, a2) in [(l1.a, l1.b), (l1.b, l1.a)] {
                        for (b1, b2) in [(l2.a, l2.b), (l2.b, l2.a)] {
                            guard Set([a1, a2, b1, b2]).count == 4, Geometry.sees(a2, b1) else { continue }
                            // Skip if the ends are already in one house (it'd be a plain locked set).
                            guard classify(l1, l2, a2, b1) == kind else { continue }
                            let targets = Geometry.commonPeers(CellSet([a1, b2])) - CellSet([a1, a2, b1, b2])
                            let elims = b.filter(targets, d).map { Candidate($0, d) }
                            guard !elims.isEmpty else { continue }
                            out.add(Step(technique, eliminations: elims, houses: [l1.house, l2.house],
                                         highlights: [Highlight(a1, d, .pattern), Highlight(a2, d, .secondary),
                                                      Highlight(b1, d, .secondary), Highlight(b2, d, .pattern)],
                                         links: [ChainLink(from: [Candidate(a1, d)], to: [Candidate(a2, d)], isStrong: true),
                                                 ChainLink(from: [Candidate(a2, d)], to: [Candidate(b1, d)], isStrong: false),
                                                 ChainLink(from: [Candidate(b1, d)], to: [Candidate(b2, d)], isStrong: true)],
                                         explanation: "\(technique.name) on \(d): \(Geometry.cellName(a1)) and \(Geometry.cellName(a2)) are the only \(d)s in \(Geometry.houseName(l1.house)); \(Geometry.cellName(b1)) and \(Geometry.cellName(b2)) are the only \(d)s in \(Geometry.houseName(l2.house)). \(Geometry.cellName(a2)) and \(Geometry.cellName(b1)) can't both be \(d), so \(Geometry.cellName(a1)) or \(Geometry.cellName(b2)) is \(d): \(describeEliminations(elims))."))
                            if out.done { return }
                        }
                    }
                }
            }
        }
    }
}

struct EmptyRectangle: Strategy {
    let technique = Technique.emptyRectangle
    func find(_ b: Board, _ out: inout StepCollector) {
        for d in 1...9 {
            let links = strongLinks(b, d).filter { $0.house < 18 }
            for box in 0..<9 {
                let inBox = b.filter(Geometry.houseSets[18 + box], d)
                guard inBox.count >= 2 else { continue }
                let r0 = (box / 3) * 3, c0 = (box % 3) * 3
                for r in r0..<r0 + 3 {
                    for c in c0..<c0 + 3 {
                        let rowPart = inBox.filter { Geometry.rowOf[$0] == r }
                        let colPart = inBox.filter { Geometry.colOf[$0] == c }
                        guard rowPart.count + colPart.count - (inBox.contains(r * 9 + c) ? 1 : 0) == inBox.count else { continue }
                        // Must not be confined to just the row or just the column.
                        guard inBox.contains(where: { Geometry.rowOf[$0] != r }),
                              inBox.contains(where: { Geometry.colOf[$0] != c }) else { continue }
                        for l in links {
                            for (x, y) in [(l.a, l.b), (l.b, l.a)] {
                                var target = -1
                                if Geometry.kind(l.house) == .column {
                                    // column strong link outside the box; x in row r
                                    let lc = Geometry.colOf[x]
                                    guard lc / 3 != box % 3, Geometry.rowOf[x] == r, Geometry.rowOf[y] / 3 != box / 3 else { continue }
                                    target = Geometry.rowOf[y] * 9 + c
                                } else {
                                    let lr = Geometry.rowOf[x]
                                    guard lr / 3 != box / 3, Geometry.colOf[x] == c, Geometry.colOf[y] / 3 != box % 3 else { continue }
                                    target = r * 9 + Geometry.colOf[y]
                                }
                                guard b.has(target, d) else { continue }
                                let elims = [Candidate(target, d)]
                                out.add(Step(technique, eliminations: elims, houses: [18 + box, l.house],
                                             highlights: inBox.map { Highlight($0, d, .pattern) } + [Highlight(x, d, .secondary), Highlight(y, d, .secondary)],
                                             explanation: "Empty Rectangle on \(d): in \(Geometry.houseName(18 + box)) every \(d) lies in row \(r + 1) or column \(c + 1). With the strong link \(Geometry.cellName(x))–\(Geometry.cellName(y)) in \(Geometry.houseName(l.house)), \(Geometry.cellName(target)) can't be \(d) either way: \(describeEliminations(elims))."))
                                if out.done { return }
                            }
                        }
                    }
                }
            }
        }
    }
}
