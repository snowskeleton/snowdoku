struct Pointing: Strategy {
    let technique = Technique.pointing
    func find(_ b: Board, _ out: inout StepCollector) {
        for box in 0..<9 {
            let h = 18 + box
            for d in 1...9 {
                let pos = b.positions(d, h)
                guard pos.count >= 2 else { continue }
                for lineHouse in Geometry.sharedHouses(pos) where lineHouse < 18 {
                    let elims = Geometry.houses[lineHouse].filter { Geometry.boxOf[$0] != box && b.has($0, d) }
                    guard !elims.isEmpty else { continue }
                    out.add(Step(technique, eliminations: cands(elims, d), houses: [h, lineHouse],
                                 highlights: pos.map { Highlight($0, d, .pattern) },
                                 explanation: "In \(Geometry.houseName(h)), \(d) is confined to \(Geometry.houseName(lineHouse)), so \(d) can be removed from the rest of \(Geometry.houseName(lineHouse)): \(describeEliminations(cands(elims, d)))."))
                    if out.done { return }
                }
            }
        }
    }
}

struct Claiming: Strategy {
    let technique = Technique.claiming
    func find(_ b: Board, _ out: inout StepCollector) {
        for h in 0..<18 {
            for d in 1...9 {
                let pos = b.positions(d, h)
                guard pos.count >= 2 else { continue }
                let box = Geometry.boxOf[pos[0]]
                guard pos.allSatisfy({ Geometry.boxOf[$0] == box }) else { continue }
                let bh = 18 + box
                let elims = Geometry.houses[bh].filter { !Geometry.houseSets[h].contains($0) && b.has($0, d) }
                guard !elims.isEmpty else { continue }
                out.add(Step(technique, eliminations: cands(elims, d), houses: [h, bh],
                             highlights: pos.map { Highlight($0, d, .pattern) },
                             explanation: "In \(Geometry.houseName(h)), \(d) is confined to \(Geometry.houseName(bh)), so \(d) can be removed from the rest of that box: \(describeEliminations(cands(elims, d)))."))
                if out.done { return }
            }
        }
    }
}

struct NakedSubset: Strategy {
    let size: Int
    var technique: Technique { [2: .nakedPair, 3: .nakedTriple, 4: .nakedQuad][size]! }
    func find(_ b: Board, _ out: inout StepCollector) {
        for h in 0..<27 {
            let empty = Geometry.houses[h].filter { b.isEmpty($0) }
            guard empty.count > size else { continue }
            let pool = empty.filter { let n = b.candidates[$0].nonzeroBitCount; return n >= 2 && n <= size }
            guard pool.count >= size else { continue }
            forEachCombination(pool.count, size) { idx in
                let set = idx.map { pool[$0] }
                let u = b.union(set)
                guard u.nonzeroBitCount == size else { return true }
                var elims: [Candidate] = []
                for c in empty where !set.contains(c) {
                    for d in Mask.digits(b.candidates[c] & u) { elims.append(Candidate(c, d)) }
                }
                guard !elims.isEmpty else { return true }
                let ds = Mask.digits(u).map(String.init).joined(separator: "/")
                out.add(Step(technique, eliminations: elims, houses: [h],
                             highlights: set.flatMap { c in Mask.digits(b.candidates[c]).map { Highlight(c, $0, .pattern) } },
                             explanation: "\(Geometry.cellsName(set)) in \(Geometry.houseName(h)) can only hold \(ds), so those digits are locked there: \(describeEliminations(elims))."))
                return !out.done
            }
            if out.done { return }
        }
    }
}

struct HiddenSubset: Strategy {
    let size: Int
    var technique: Technique { [2: .hiddenPair, 3: .hiddenTriple, 4: .hiddenQuad][size]! }
    func find(_ b: Board, _ out: inout StepCollector) {
        for h in 0..<27 {
            let unplaced = (1...9).filter { !b.isPlaced($0, in: h) }
            guard unplaced.count > size else { continue }
            let masks = unplaced.map { b.positionMask($0, h) }
            let pool = unplaced.indices.filter { (2...size).contains(masks[$0].nonzeroBitCount) }
            guard pool.count >= size else { continue }
            let house = Geometry.houses[h]
            forEachCombination(pool.count, size) { idx in
                var pm: UInt16 = 0
                for i in idx { pm |= masks[pool[i]] }
                guard pm.nonzeroBitCount == size else { return true }
                let digits = idx.map { unplaced[pool[$0]] }
                let dm = Mask.from(digits)
                let cells = Mask.indices(pm).map { house[$0] }
                var elims: [Candidate] = []
                for c in cells { for d in Mask.digits(b.candidates[c] & ~dm) { elims.append(Candidate(c, d)) } }
                guard !elims.isEmpty else { return true }
                out.add(Step(technique, eliminations: elims, houses: [h],
                             highlights: cells.flatMap { c in digits.filter { b.has(c, $0) }.map { Highlight(c, $0, .pattern) } },
                             explanation: "In \(Geometry.houseName(h)), \(digits.map(String.init).joined(separator: "/")) only fit in \(Geometry.cellsName(cells)), so other candidates there can go: \(describeEliminations(elims))."))
                return !out.done
            }
            if out.done { return }
        }
    }
}
