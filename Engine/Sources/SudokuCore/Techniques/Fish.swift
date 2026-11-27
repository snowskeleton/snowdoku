/// Basic, finned and sashimi fish (X-Wing, Swordfish, Jellyfish) on rows/columns.
///
/// This runs at nearly every step of a hard solve, so the search works on bitmasks and allocates
/// only when it reports a step. It visits base and cover sets in the same order as a plain
/// "every base combination, every cover combination" search, so it finds the same first step.
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

    var fishName: String { size == 2 ? "X-Wing" : size == 3 ? "Swordfish" : "Jellyfish" }

    /// Cross indices of each stack (or band): bits 0-2, 3-5, 6-8.
    static let thirds: [UInt16] = [0b000_000_111, 0b000_111_000, 0b111_000_000]

    func find(_ b: Board, _ out: inout StepCollector) {
        var lineIdx = [Int](repeating: 0, count: 9)
        var lineMask = [UInt16](repeating: 0, count: 9)
        var covers: [UInt16] = []
        covers.reserveCapacity(16)
        let maxPositions = kind == .basic ? size : size + 3
        for d in 1...9 {
            for rowsBase in [true, false] {
                // lines: base line index + position mask (bit k = cross index k)
                var count = 0
                for i in 0..<9 {
                    let m = b.positionMask(d, rowsBase ? i : 9 + i)
                    let n = m.nonzeroBitCount
                    if n == 0 || n > maxPositions { continue }
                    lineIdx[count] = i; lineMask[count] = m; count += 1
                }
                guard count >= size else { continue }

                forEachCombination(count, size) { idx in
                    var baseSet: UInt16 = 0, union: UInt16 = 0
                    for i in idx { baseSet |= 1 << UInt16(lineIdx[i]); union |= lineMask[i] }
                    let n = union.nonzeroBitCount

                    if kind == .basic {
                        guard n == size else { return true }
                        guard hasTarget(b, d, rowsBase, baseSet, cover: union, finBox: -1) else { return true }
                        report(b, d, rowsBase, idx.map { (lineIdx[$0], lineMask[$0]) }, baseSet, cover: union, out: &out)
                        return !out.done
                    }

                    guard n > size else { return true }
                    // Fins must share a box, so the cover takes every union line outside one stack
                    // and all but at least one of the lines inside it.
                    covers.removeAll(keepingCapacity: true)
                    for stack in Self.thirds {
                        let required = union & ~stack
                        let need = size - required.nonzeroBitCount
                        guard need >= 0 else { continue }
                        let optional = union & stack
                        var sub = optional
                        while true {  // every subset of optional with `need` bits, leaving a fin
                            if sub.nonzeroBitCount == need && sub != optional { covers.append(required | sub) }
                            if sub == 0 { break }
                            sub = (sub &- 1) & optional
                        }
                    }
                    // The order a combination-by-combination search over the union would visit them.
                    covers.sort { a, c in let x = a ^ c; return a & x & (0 &- x) != 0 }
                    for cover in covers {
                        // The lines holding fins must share a band too.
                        var finBand = -1, finLine = 0, sameBand = true, sashimi = false
                        for i in idx {
                            let m = lineMask[i]
                            if m & ~cover != 0 {
                                let band = lineIdx[i] / 3
                                if finBand >= 0 && band != finBand { sameBand = false; break }
                                finBand = band; finLine = lineIdx[i]
                            }
                            if (m & cover).nonzeroBitCount <= 1 { sashimi = true }
                        }
                        guard sameBand, sashimi == (kind == .sashimi) else { continue }
                        let finCross = (union & ~cover).trailingZeroBitCount
                        let finBox = rowsBase ? Geometry.boxOf[finLine * 9 + finCross] : Geometry.boxOf[finCross * 9 + finLine]
                        guard hasTarget(b, d, rowsBase, baseSet, cover: cover, finBox: finBox) else { continue }
                        report(b, d, rowsBase, idx.map { (lineIdx[$0], lineMask[$0]) }, baseSet, cover: cover, out: &out)
                        if out.done { return false }
                    }
                    return true
                }
                if out.done { return }
            }
        }
    }

    /// Whether the cover lines hold `d` outside the base lines (and, for a finned fish, in the fin box).
    private func hasTarget(_ b: Board, _ d: Int, _ rowsBase: Bool, _ baseSet: UInt16, cover: UInt16, finBox: Int) -> Bool {
        var m = cover
        while m != 0 {
            let cross = m.trailingZeroBitCount
            m &= m &- 1
            let others = b.positionMask(d, rowsBase ? 9 + cross : cross) & ~baseSet
            var o = others
            while o != 0 {
                let j = o.trailingZeroBitCount
                o &= o &- 1
                if finBox < 0 || Geometry.boxOf[rowsBase ? j * 9 + cross : cross * 9 + j] == finBox { return true }
            }
        }
        return false
    }

    /// Builds and records the step for one base/cover pair, if it eliminates anything.
    private func report(_ b: Board, _ d: Int, _ rowsBase: Bool, _ base: [(Int, UInt16)], _ baseSet: UInt16,
                        cover: UInt16, out: inout StepCollector) {
        let cellAt: (Int, Int) -> Int = { base, cross in rowsBase ? base * 9 + cross : cross * 9 + base }
        let baseWord = rowsBase ? "rows" : "columns", coverWord = rowsBase ? "columns" : "rows"
        let baseNames = base.map { String($0.0 + 1) }.joined(separator: ",")
        let coverNames = Mask.indices(cover).map { String($0 + 1) }.joined(separator: ",")
        let pattern = base.flatMap { l in Mask.indices(l.1).map { cellAt(l.0, $0) } }

        if kind == .basic {
            var elims: [Candidate] = []
            for cross in Mask.indices(cover) {
                for j in 0..<9 where baseSet & (1 << UInt16(j)) == 0 {
                    let c = cellAt(j, cross)
                    if b.has(c, d) { elims.append(Candidate(c, d)) }
                }
            }
            guard !elims.isEmpty else { return }
            out.add(Step(technique, eliminations: elims,
                         houses: base.map { rowsBase ? $0.0 : 9 + $0.0 } + Mask.indices(cover).map { rowsBase ? 9 + $0 : $0 },
                         highlights: pattern.map { Highlight($0, d, .pattern) },
                         explanation: "\(fishName) on \(d): in \(baseWord) \(baseNames), \(d) is confined to \(coverWord) \(coverNames). One \(d) per \(coverWord.dropLast()) is used up, so \(describeEliminations(elims))."))
            return
        }

        var fins: [Int] = []
        for l in base { for k in Mask.indices(l.1 & ~cover) { fins.append(cellAt(l.0, k)) } }
        let finBox = Geometry.boxOf[fins[0]]
        var elims: [Candidate] = []
        for cross in Mask.indices(cover) {
            for j in 0..<9 where baseSet & (1 << UInt16(j)) == 0 {
                let c = cellAt(j, cross)
                if Geometry.boxOf[c] == finBox && b.has(c, d) { elims.append(Candidate(c, d)) }
            }
        }
        guard !elims.isEmpty else { return }
        let finSet = Set(fins)
        out.add(Step(technique, eliminations: elims,
                     houses: base.map { rowsBase ? $0.0 : 9 + $0.0 } + Mask.indices(cover).map { rowsBase ? 9 + $0 : $0 } + [18 + finBox],
                     highlights: pattern.map { Highlight($0, d, finSet.contains($0) ? .fin : .pattern) },
                     explanation: "\(technique.name) on \(d): \(baseWord) \(baseNames) would form a \(fishName) on \(coverWord) \(coverNames) except for the fin\(fins.count > 1 ? "s" : "") at \(Geometry.cellsName(fins)). Either the fish holds or a fin is true; both remove \(d) from cells that see the fins: \(describeEliminations(elims))."))
    }
}
