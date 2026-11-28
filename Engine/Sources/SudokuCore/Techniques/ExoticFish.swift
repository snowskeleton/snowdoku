/// Franken and Mutant fish: base and cover sets drawn from rows, columns and boxes.
///
/// Candidates shared by two base houses (a box and a line) are endo fins; base candidates outside
/// the cover are exo fins. If no fin is true, each base house holds the digit in its own cells, so
/// each cover house holds exactly one of them: cover candidates outside the base die, as do base
/// candidates covered twice (cannibals). With fins, targets must also see every fin.
struct GeneralFish: Strategy {
    enum Kind: Sendable { case franken, mutant }
    let kind: Kind
    var technique: Technique { kind == .franken ? .frankenFish : .mutantFish }

    static let rows = Array(0..<9), cols = Array(9..<18), boxes = Array(18..<27)

    func find(_ b: Board, _ out: inout StepCollector) {
        let pools: [([Int], [Int])] = kind == .franken
            ? [(Self.rows + Self.boxes, Self.cols + Self.boxes), (Self.cols + Self.boxes, Self.rows + Self.boxes)]
            : [(Array(0..<27), Array(0..<27))]
        // Scratch space reused for every base set, so the search itself doesn't allocate.
        var coverCands = [Int](repeating: 0, count: 27)
        var coverCount = [Int](repeating: 0, count: 27)  // base cells each candidate covers
        var suffixMax = [Int](repeating: 0, count: 28)   // largest coverCount from index i on
        for d in 1...9 {
            let hc: [CellSet] = (0..<27).map { b.filter(Geometry.houseSets[$0], d) }
            for (basePool, coverPool) in pools {
                let bases = basePool.filter { !hc[$0].isEmpty }
                let nb = bases.count
                for size in 2...3 where nb >= size {
                    // Base sets in combination order. Cells in two base houses are endo fins, at most
                    // two of them, so a pair that already shares more rules out every set containing it.
                    func evaluate(_ b0: Int, _ b1: Int, _ b2: Int) -> Bool {
                        var baseCells = hc[b0] | hc[b1]
                        var endo = hc[b0] & hc[b1]
                        var baseHouses: UInt32 = 1 << UInt32(b0) | 1 << UInt32(b1)
                        var baseKinds = Self.kindBit[b0] | Self.kindBit[b1]
                        if b2 >= 0 {
                            endo |= baseCells & hc[b2]
                            baseCells |= hc[b2]
                            baseHouses |= 1 << UInt32(b2)
                            baseKinds |= Self.kindBit[b2]
                        }
                        guard endo.count <= 2 else { return true }
                        var m = 0
                        for h in coverPool where baseHouses & (1 << UInt32(h)) == 0 {
                            let k = (hc[h] & baseCells).count
                            if k > 0 { coverCands[m] = h; coverCount[m] = k; m += 1 }
                        }
                        guard m >= size else { return true }
                        suffixMax[m] = 0
                        for i in stride(from: m - 1, through: 0, by: -1) { suffixMax[i] = max(coverCount[i], suffixMax[i + 1]) }

                        func tryCover(_ h0: Int, _ h1: Int, _ h2: Int) -> Bool {
                            var coverCells = hc[h0] | hc[h1]
                            var twice = hc[h0] & hc[h1]
                            var coverKinds = Self.kindBit[h0] | Self.kindBit[h1]
                            if h2 >= 0 {
                                twice |= coverCells & hc[h2]
                                coverCells |= hc[h2]
                                coverKinds |= Self.kindBit[h2]
                            }
                            let fins = (baseCells - coverCells) | endo
                            guard fins.count <= 3, Self.classify(baseKinds, coverKinds) == kind else { return true }
                            var targets = (coverCells - baseCells) | ((baseCells - fins) & twice)
                            if !fins.isEmpty { targets &= Geometry.commonPeers(fins) }
                            guard !targets.isEmpty else { return true }
                            let bh = b2 >= 0 ? [b0, b1, b2] : [b0, b1]
                            let ch = h2 >= 0 ? [h0, h1, h2] : [h0, h1]
                            let elims = targets.map { Candidate($0, d) }
                            out.add(Step(technique, eliminations: elims, houses: bh + ch,
                                         highlights: baseCells.map { Highlight($0, d, fins.contains($0) ? .fin : .pattern) },
                                         complexity: size,
                                         explanation: "\(technique.name) on \(d): the base houses \(bh.map(Geometry.houseName).joined(separator: ", ")) hold \(size) separate \(d)s\(endo.isEmpty ? "" : " (\(Geometry.cellsName(endo)) belong to two of them, so they count as fins)"), all inside the cover houses \(ch.map(Geometry.houseName).joined(separator: ", "))\(fins.isEmpty ? "" : " apart from the fin\(fins.count > 1 ? "s" : "") \(Geometry.cellsName(fins))"). Each cover house is used up\(fins.isEmpty ? "" : " (or a fin is true)"): \(describeEliminations(elims))."))
                            return !out.done
                        }

                        // Base cells outside the cover are fins, at most three of them, so skip partial
                        // covers that the remaining candidates can't bring under that.
                        for i in 0..<m {
                            let h0 = coverCands[i]
                            guard (baseCells - hc[h0]).count - (size - 1) * suffixMax[i + 1] <= 3 else { continue }
                            for j in (i + 1)..<m {
                                let h1 = coverCands[j]
                                if size == 2 {
                                    if !tryCover(h0, h1, -1) { return false }
                                    continue
                                }
                                guard (baseCells - hc[h0] - hc[h1]).count - suffixMax[j + 1] <= 3 else { continue }
                                for k in (j + 1)..<m {
                                    if !tryCover(h0, h1, coverCands[k]) { return false }
                                }
                            }
                        }
                        return true
                    }

                    search: for i in 0..<nb {
                        for j in (i + 1)..<nb {
                            if size == 2 {
                                if !evaluate(bases[i], bases[j], -1) { break search }
                                continue
                            }
                            guard (hc[bases[i]] & hc[bases[j]]).count <= 2 else { continue }
                            for k in (j + 1)..<nb {
                                if !evaluate(bases[i], bases[j], bases[k]) { break search }
                            }
                        }
                    }
                    if out.done { return }
                }
            }
        }
    }

    /// 1 = row, 2 = column, 4 = box, per house.
    static let kindBit: [Int] = (0..<27).map { $0 < 9 ? 1 : $0 < 18 ? 2 : 4 }

    /// Basic (rows vs columns) is nil: those are ordinary fish. Franken keeps one line direction
    /// out of each side; anything else is mutant.
    static func classify(_ base: Int, _ cover: Int) -> Kind? {
        if (base == 1 && cover == 2) || (base == 2 && cover == 1) { return nil }
        let franken = (base & 2 == 0 && cover & 1 == 0) || (base & 1 == 0 && cover & 2 == 0)
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
                        var union: UInt16 = 0, baseSet: UInt16 = 0
                        for i in idx { union |= lines[i].1; baseSet |= 1 << UInt16(lines[i].0) }
                        guard union.nonzeroBitCount > size else { return true }
                        let base = idx.map { lines[$0] }
                        let crossList = Mask.indices(union)
                        forEachCombination(crossList.count, size) { cidx in
                            var cover: UInt16 = 0
                            for i in cidx { cover |= 1 << UInt16(crossList[i]) }
                            var finCount = 0
                            for l in base { finCount += (l.1 & ~cover).nonzeroBitCount }
                            guard (1...3).contains(finCount) else { return true }
                            var fins: [Int] = []
                            for l in base { for k in Mask.indices(l.1 & ~cover) { fins.append(cellAt(l.0, k)) } }
                            guard (1...3).contains(fins.count) else { return true }
                            if fins.allSatisfy({ Geometry.boxOf[$0] == Geometry.boxOf[fins[0]] }) { return true }
                            var elims: [Candidate] = []
                            for cross in Mask.indices(cover) {
                                for j in 0..<9 where baseSet & (1 << UInt16(j)) == 0 {
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
