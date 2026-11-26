/// Franken and Mutant fish: base and cover sets drawn from rows, columns and boxes.
///
/// Base houses must not share candidates (no endo-fins). If no fin is true, each cover
/// house holds exactly one of the base digits, so cover candidates outside the base die,
/// as do base candidates covered twice (cannibals). With fins, targets must also see every fin.
struct GeneralFish: Strategy {
    enum Kind: Sendable { case franken, mutant }
    let kind: Kind
    var technique: Technique { kind == .franken ? .frankenFish : .mutantFish }

    static let rows = Array(0..<9), cols = Array(9..<18), boxes = Array(18..<27)

    func find(_ b: Board, _ out: inout StepCollector) {
        let pools: [([Int], [Int])] = kind == .franken
            ? [(Self.rows + Self.boxes, Self.cols + Self.boxes), (Self.cols + Self.boxes, Self.rows + Self.boxes)]
            : [(Array(0..<27), Array(0..<27))]
        for d in 1...9 {
            let hc: [CellSet] = (0..<27).map { b.filter(Geometry.houseSets[$0], d) }
            for (basePool, coverPool) in pools {
                let bases = basePool.filter { !hc[$0].isEmpty }
                for size in 2...3 {
                    forEachCombination(bases.count, size) { idx in
                        let bh = idx.map { bases[$0] }
                        var baseCells = CellSet()
                        for h in bh {
                            if !(baseCells & hc[h]).isEmpty { return true }
                            baseCells |= hc[h]
                        }
                        let coverCands = coverPool.filter { !bh.contains($0) && !(hc[$0] & baseCells).isEmpty }
                        guard coverCands.count >= size else { return true }
                        forEachCombination(coverCands.count, size) { cidx in
                            let ch = cidx.map { coverCands[$0] }
                            guard classify(bh, ch) == kind else { return true }
                            var coverCells = CellSet()
                            for h in ch { coverCells |= hc[h] }
                            let fins = baseCells - coverCells
                            guard fins.count <= 3 else { return true }
                            var targets = coverCells - baseCells
                            for c in baseCells where ch.filter({ hc[$0].contains(c) }).count >= 2 { targets.insert(c) }
                            if !fins.isEmpty { targets &= Geometry.commonPeers(fins) }
                            guard !targets.isEmpty else { return true }
                            let elims = targets.map { Candidate($0, d) }
                            out.add(Step(technique, eliminations: elims, houses: bh + ch,
                                         highlights: baseCells.map { Highlight($0, d, fins.contains($0) ? .fin : .pattern) },
                                         complexity: size,
                                         explanation: "\(technique.name) on \(d): the base houses \(bh.map(Geometry.houseName).joined(separator: ", ")) hold \(size) separate \(d)s, all inside the cover houses \(ch.map(Geometry.houseName).joined(separator: ", "))\(fins.isEmpty ? "" : " apart from the fin\(fins.count > 1 ? "s" : "") \(Geometry.cellsName(fins))"). Each cover house is used up\(fins.isEmpty ? "" : " (or a fin is true)"): \(describeEliminations(elims))."))
                            return !out.done
                        }
                        return !out.done
                    }
                    if out.done { return }
                }
            }
        }
    }

    func classify(_ base: [Int], _ cover: [Int]) -> Kind? {
        func all(_ hs: [Int], _ ok: (Geometry.HouseKind) -> Bool) -> Bool { hs.allSatisfy { ok(Geometry.kind($0)) } }
        let basic = (all(base) { $0 == .row } && all(cover) { $0 == .column }) || (all(base) { $0 == .column } && all(cover) { $0 == .row })
        if basic { return nil }
        let franken = (all(base) { $0 != .column } && all(cover) { $0 != .row }) || (all(base) { $0 != .row } && all(cover) { $0 != .column })
        return franken ? .franken : .mutant
    }
}

/// Kraken fish: a row/column fish whose fins are scattered. A target dies if the fish kills it
/// and every fin, assumed true, also kills it via propagation.
struct KrakenFish: Strategy {
    let technique = Technique.krakenFish

    func find(_ b: Board, _ out: inout StepCollector) {
        var cache: [Int: Board] = [:]
        var impossible = Set<Int>()
        func outcome(_ c: Int, _ d: Int) -> Board? {
            let key = c * 10 + d
            if impossible.contains(key) { return nil }
            if let r = cache[key] { return r }
            var x = b
            x.place(c, d)
            if let r = propagateSingles(x) { cache[key] = r; return r }
            impossible.insert(key)
            return nil
        }
        for d in 1...9 {
            for rowsBase in [true, false] {
                let cellAt: (Int, Int) -> Int = { base, cross in rowsBase ? base * 9 + cross : cross * 9 + base }
                var lines: [(Int, UInt16)] = []
                for i in 0..<9 {
                    let m = b.positionMask(d, rowsBase ? i : 9 + i)
                    if m != 0 && m.nonzeroBitCount <= 5 { lines.append((i, m)) }
                }
                for size in 2...3 where lines.count >= size {
                    forEachCombination(lines.count, size) { idx in
                        let base = idx.map { lines[$0] }
                        let baseIdx = Set(base.map(\.0))
                        var union: UInt16 = 0
                        for l in base { union |= l.1 }
                        guard union.nonzeroBitCount > size else { return true }
                        let crossList = Mask.indices(union)
                        forEachCombination(crossList.count, size) { cidx in
                            var cover: UInt16 = 0
                            for i in cidx { cover |= 1 << UInt16(crossList[i]) }
                            var fins: [Int] = []
                            for l in base { for k in Mask.indices(l.1 & ~cover) { fins.append(cellAt(l.0, k)) } }
                            guard (1...3).contains(fins.count) else { return true }
                            if fins.allSatisfy({ Geometry.boxOf[$0] == Geometry.boxOf[fins[0]] }) { return true }
                            var elims: [Candidate] = []
                            for cross in Mask.indices(cover) {
                                for j in 0..<9 where !baseIdx.contains(j) {
                                    let t = cellAt(j, cross)
                                    guard b.has(t, d) else { continue }
                                    let killed = fins.allSatisfy { f in
                                        guard let r = outcome(f, d) else { return true }
                                        return !r.has(t, d) && r.value(t) != d
                                    }
                                    if killed { elims.append(Candidate(t, d)) }
                                }
                            }
                            guard !elims.isEmpty else { return true }
                            let finSet = Set(fins)
                            let pattern = base.flatMap { l in Mask.indices(l.1).map { cellAt(l.0, $0) } }
                            out.add(Step(technique, eliminations: elims,
                                         highlights: pattern.map { Highlight($0, d, finSet.contains($0) ? .fin : .pattern) },
                                         complexity: size + fins.count,
                                         explanation: "Kraken Fish on \(d): without the fins \(Geometry.cellsName(fins)) this is a fish on \(rowsBase ? "columns" : "rows") \(Mask.indices(cover).map { String($0 + 1) }.joined(separator: ",")). Either the fish holds, or one fin is true, and following each fin also removes the target: \(describeEliminations(elims))."))
                            return !out.done
                        }
                        return !out.done
                    }
                    if out.done { return }
                }
            }
        }
    }
}

/// Chains of 4-5 ALSs linked by restricted common candidates (shorter ones are ALS-XZ / ALS-XY-Wing).
struct ALSChain: Strategy {
    let technique = Technique.alsChain

    func find(_ b: Board, _ out: inout StepCollector) {
        let sets = findALS(b, maxSize: 4)
        var nbrs: [[(Int, DigitMask)]] = Array(repeating: [], count: sets.count)
        for i in 0..<sets.count {
            for j in (i + 1)..<max(i + 1, sets.count) {
                let r = restrictedCommons(sets[i], sets[j])
                if r != 0 { nbrs[i].append((j, r)); nbrs[j].append((i, r)) }
            }
        }
        var budget = 400_000
        var path: [Int] = []
        var rccs: [Int] = []

        func dfs(_ cur: Int, _ used: CellSet) -> Bool {
            if path.count >= 4 {
                let A = sets[path[0]], Z = sets[cur]
                let zs = A.digits & Z.digits & ~Mask.bit(rccs[0]) & ~Mask.bit(rccs[rccs.count - 1])
                var elims: [Candidate] = []
                for z in Mask.digits(zs) {
                    let zc = A.byDigit[z] | Z.byDigit[z]
                    elims += b.filter(Geometry.commonPeers(zc) - A.cells - Z.cells, z).map { Candidate($0, z) }
                }
                if !elims.isEmpty {
                    let chain = path.map { sets[$0] }
                    var text = chain[0].name
                    for (i, x) in rccs.enumerated() { text += " -\(x)- " + chain[i + 1].name }
                    out.add(Step(technique, eliminations: elims, highlights: alsHighlights(chain, b), complexity: path.count,
                                 explanation: "ALS Chain: \(text). If the first set doesn't hold the common digit, each set in turn becomes locked along the chain, so the last one does: \(describeEliminations(elims))."))
                    if out.done { return false }
                }
            }
            if path.count == 5 { return true }
            for (n, mask) in nbrs[cur] where sets[n].cells.isDisjoint(with: used) {
                for x in Mask.digits(mask) where rccs.last != x {
                    budget -= 1
                    if budget <= 0 { return false }
                    path.append(n); rccs.append(x)
                    let cont = dfs(n, used | sets[n].cells)
                    path.removeLast(); rccs.removeLast()
                    if !cont { return false }
                }
            }
            return true
        }

        for s in sets.indices {
            path = [s]; rccs = []
            if !dfs(s, sets[s].cells) { return }
        }
    }
}
