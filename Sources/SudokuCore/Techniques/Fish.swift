/// Basic, finned and sashimi fish (X-Wing, Swordfish, Jellyfish) on rows/columns.
struct Fish: Strategy {
    enum Kind: Sendable { case basic, finned, sashimi }
    let size: Int
    let kind: Kind

    var technique: Technique {
        switch (size, kind) {
        case (2, .basic): .xWing
        case (3, .basic): .swordfish
        case (4, .basic): .jellyfish
        case (2, .finned): .finnedXWing
        case (3, .finned): .finnedSwordfish
        case (4, .finned): .finnedJellyfish
        case (2, _): .sashimiXWing
        case (3, _): .sashimiSwordfish
        default: .sashimiJellyfish
        }
    }

    func find(_ b: Board, _ out: inout StepCollector) {
        let names = [2: "X-Wing", 3: "Swordfish", 4: "Jellyfish"]
        for d in 1...9 {
            for rowsBase in [true, false] {
                // lines: base line index + position mask (bit k = cross index k)
                var lines: [(Int, UInt16)] = []
                for i in 0..<9 {
                    let m = b.positionMask(d, rowsBase ? i : 9 + i)
                    let n = m.nonzeroBitCount
                    if n == 0 { continue }
                    if kind == .basic ? n <= size : n <= size + 3 { lines.append((i, m)) }
                }
                guard lines.count >= size else { continue }
                let cellAt: (Int, Int) -> Int = { base, cross in rowsBase ? base * 9 + cross : cross * 9 + base }
                let baseWord = rowsBase ? "rows" : "columns", coverWord = rowsBase ? "columns" : "rows"

                forEachCombination(lines.count, size) { idx in
                    let base = idx.map { lines[$0] }
                    let baseIdx = Set(base.map(\.0))
                    var union: UInt16 = 0
                    for l in base { union |= l.1 }
                    let n = union.nonzeroBitCount

                    if kind == .basic {
                        guard n == size else { return true }
                        var elims: [Candidate] = []
                        for cross in Mask.indices(union) {
                            for j in 0..<9 where !baseIdx.contains(j) {
                                let c = cellAt(j, cross)
                                if b.has(c, d) { elims.append(Candidate(c, d)) }
                            }
                        }
                        guard !elims.isEmpty else { return true }
                        let pattern = base.flatMap { l in Mask.indices(l.1).map { cellAt(l.0, $0) } }
                        out.add(Step(technique, eliminations: elims,
                                     houses: base.map { rowsBase ? $0.0 : 9 + $0.0 } + Mask.indices(union).map { rowsBase ? 9 + $0 : $0 },
                                     highlights: pattern.map { Highlight($0, d, .pattern) },
                                     explanation: "\(names[size]!) on \(d): in \(baseWord) \(base.map { String($0.0 + 1) }.joined(separator: ",")), \(d) is confined to \(coverWord) \(Mask.indices(union).map { String($0 + 1) }.joined(separator: ",")). One \(d) per \(coverWord.dropLast()) is used up, so \(describeEliminations(elims))."))
                        return !out.done
                    }

                    guard n > size else { return true }
                    let crossList = Mask.indices(union)
                    forEachCombination(crossList.count, size) { cidx in
                        var cover: UInt16 = 0
                        for i in cidx { cover |= 1 << UInt16(crossList[i]) }
                        // fins: base candidates outside the cover lines
                        var fins: [Int] = []
                        for l in base { for k in Mask.indices(l.1 & ~cover) { fins.append(cellAt(l.0, k)) } }
                        guard !fins.isEmpty else { return true }
                        let finBox = Geometry.boxOf[fins[0]]
                        guard fins.allSatisfy({ Geometry.boxOf[$0] == finBox }) else { return true }
                        let isSashimi = base.contains { ($0.1 & cover).nonzeroBitCount <= 1 }
                        guard isSashimi == (kind == .sashimi) else { return true }
                        var elims: [Candidate] = []
                        for cross in Mask.indices(cover) {
                            for j in 0..<9 where !baseIdx.contains(j) {
                                let c = cellAt(j, cross)
                                if Geometry.boxOf[c] == finBox && b.has(c, d) { elims.append(Candidate(c, d)) }
                            }
                        }
                        guard !elims.isEmpty else { return true }
                        let finSet = Set(fins)
                        let pattern = base.flatMap { l in Mask.indices(l.1).map { cellAt(l.0, $0) } }
                        out.add(Step(technique, eliminations: elims,
                                     houses: base.map { rowsBase ? $0.0 : 9 + $0.0 } + Mask.indices(cover).map { rowsBase ? 9 + $0 : $0 } + [18 + finBox],
                                     highlights: pattern.map { Highlight($0, d, finSet.contains($0) ? .fin : .pattern) },
                                     explanation: "\(technique.name) on \(d): \(baseWord) \(base.map { String($0.0 + 1) }.joined(separator: ",")) would form a \(names[size]!) on \(coverWord) \(Mask.indices(cover).map { String($0 + 1) }.joined(separator: ",")) except for the fin\(fins.count > 1 ? "s" : "") at \(Geometry.cellsName(fins)). Either the fish holds or a fin is true; both remove \(d) from cells that see the fins: \(describeEliminations(elims))."))
                        return !out.done
                    }
                    return !out.done
                }
                if out.done { return }
            }
        }
    }
}
