struct FullHouse: Strategy {
    let technique = Technique.fullHouse
    func find(_ b: Board, _ out: inout StepCollector) {
        for h in 0..<27 {
            var empty = -1, n = 0
            for c in Geometry.houses[h] where b.isEmpty(c) { n += 1; empty = c }
            guard n == 1, b.candidates[empty].nonzeroBitCount == 1 else { continue }
            let d = Mask.first(b.candidates[empty])
            out.add(Step(technique, placements: [Candidate(empty, d)], houses: [h],
                         highlights: Geometry.houses[h].map { Highlight($0, 0, .secondary) },
                         explanation: "\(Geometry.cellName(empty)) is the last empty cell in \(Geometry.houseName(h)), so it must be \(d)."))
            if out.done { return }
        }
    }
}

struct HiddenSingle: Strategy {
    let inBox: Bool
    var technique: Technique { inBox ? .hiddenSingleBox : .hiddenSingleLine }
    func find(_ b: Board, _ out: inout StepCollector) {
        let range = inBox ? 18..<27 : 0..<18
        for h in range {
            for d in 1...9 {
                let pos = b.positions(d, h)
                guard pos.count == 1, !b.isPlaced(d, in: h) else { continue }
                let c = pos[0]
                // If it's also a naked single in a "full house" sense we still report the hidden single.
                out.add(Step(technique, placements: [Candidate(c, d)], houses: [h],
                             highlights: [Highlight(c, d, .pattern)],
                             explanation: "In \(Geometry.houseName(h)), \(d) can only go in \(Geometry.cellName(c))."))
                if out.done { return }
            }
        }
    }
}

struct NakedSingle: Strategy {
    let technique = Technique.nakedSingle
    func find(_ b: Board, _ out: inout StepCollector) {
        for c in 0..<81 where b.isEmpty(c) && b.candidates[c].nonzeroBitCount == 1 {
            let d = Mask.first(b.candidates[c])
            out.add(Step(technique, placements: [Candidate(c, d)], houses: Geometry.housesOfCell[c],
                         highlights: [Highlight(c, d, .pattern)],
                         explanation: "\(Geometry.cellName(c)) has only one candidate left: \(d)."))
            if out.done { return }
        }
    }
}
