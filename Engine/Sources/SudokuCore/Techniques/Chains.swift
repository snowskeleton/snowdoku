/// Alternating inference chains: X-Chains, XY-Chains, Remote Pairs, AICs and grouped AICs.
///
/// A chain A1 = A2 - A3 = A4 ... = An (strong "=" / weak "-" alternating, starting and ending strong)
/// proves "A1 or An is true". Anything that conflicts with both endpoints is eliminated.
struct ChainStrategy: Strategy {
    enum Mode: Sendable { case remotePair, x, xy, niceLoop, aic, grouped }
    let mode: Mode
    var ranked: Bool { true }
    var technique: Technique {
        switch mode {
        case .remotePair: .remotePair
        case .x: .xChain
        case .xy: .xyChain
        case .niceLoop: .niceLoop
        case .aic: .aic
        case .grouped: .groupedAIC
        }
    }
    static let maxLinks = 15

    func find(_ b: Board, _ out: inout StepCollector) {
        switch mode {
        case .x:
            for d in 1...9 { search(ChainGraph(b, mode: mode, digit: d), b, &out) }
        default:
            search(ChainGraph(b, mode: mode, digit: nil), b, &out)
        }
    }

    func search(_ g: ChainGraph, _ b: Board, _ out: inout StepCollector) {
        let n = g.nodes.count
        guard n > 0 else { return }
        var best = Self.maxLinks
        var parent = [Int32](repeating: -1, count: n * 2)
        var dist = [Int32](repeating: -1, count: n * 2)
        var queue = [Int32](repeating: 0, count: n * 2)
        for s in 0..<n where !g.nodes[s].isGroup {
            if mode == .remotePair || mode == .xy {
                // Starts in a bivalue cell.
                guard g.strong[s].contains(where: { g.nodes[$0].cells == g.nodes[s].cells }) else { continue }
            }
            for i in 0..<(n * 2) { dist[i] = -1 }
            var head = 0, tail = 0
            queue[tail] = Int32(s * 2); tail += 1
            dist[s * 2] = 0
            var found = false
            while head < tail && !found {
                let st = Int(queue[head]); head += 1
                let node = st >> 1, on = st & 1 == 1
                let dcur = Int(dist[st])
                if dcur + 1 > best { break }
                let nbrs = on ? g.weak[node] : g.strong[node]
                for nb in nbrs {
                    let ns = nb * 2 + (on ? 0 : 1)
                    guard dist[ns] < 0 else { continue }
                    dist[ns] = Int32(dcur + 1)
                    parent[ns] = Int32(st)
                    queue[tail] = Int32(ns); tail += 1
                    // Arrived at an "on" node: the chain s ... nb proves (s or nb).
                    guard !on, dcur + 1 >= 3 else { continue }
                    let path = reconstruct(ns, parent: parent, start: s * 2)
                    guard pathIsValid(path, g) else { continue }
                    if mode == .niceLoop {
                        guard nb != s, g.weak[nb].contains(s) else { continue }
                        let elims = loopEliminations(path, g, b)
                        guard !elims.isEmpty, let step = makeStep(path, g, b, elims, [], loop: true) else { continue }
                        out.add(step)
                        best = min(best, dcur + 1)
                        found = true
                        break
                    }
                    let (elims, places) = conclusions(s, nb, g, b)
                    guard !elims.isEmpty || !places.isEmpty else { continue }
                    if let step = makeStep(path, g, b, elims, places) {
                        out.add(step)
                        best = min(best, dcur + 1)
                        found = true
                        break
                    }
                }
            }
            if out.done { return }
        }
    }

    func reconstruct(_ end: Int, parent: [Int32], start: Int) -> [Int] {
        var path = [end]
        var cur = end
        while cur != start {
            cur = Int(parent[cur])
            path.append(cur)
        }
        return path.reversed()
    }

    /// Remote pair chains must stay on one pair of digits.
    func pathIsValid(_ path: [Int], _ g: ChainGraph) -> Bool {
        if mode == .remotePair {
            let first = g.nodes[path[0] >> 1].cells.first!
            let pair = g.board.candidates[first]
            return path.allSatisfy { g.board.candidates[g.nodes[$0 >> 1].cells.first!] == pair }
        }
        if mode == .grouped {
            return path.contains { g.nodes[$0 >> 1].isGroup }
        }
        if mode == .niceLoop {
            return Set(path.map { $0 >> 1 }).count == path.count
        }
        return true
    }

    /// In a continuous loop each weak link holds exactly one true end.
    func loopEliminations(_ path: [Int], _ g: ChainGraph, _ b: Board) -> [Candidate] {
        let nodes = path.map { g.nodes[$0 >> 1] }
        var inLoop = Set<Candidate>()
        for n in nodes { for c in n.cells { inLoop.insert(Candidate(c, n.digit)) } }
        var weakPairs: [(ChainGraph.Node, ChainGraph.Node)] = []
        var i = 1
        while i + 1 < nodes.count { weakPairs.append((nodes[i], nodes[i + 1])); i += 2 }
        weakPairs.append((nodes[nodes.count - 1], nodes[0]))
        var out = Set<Candidate>()
        for (p, q) in weakPairs {
            if p.digit == q.digit {
                for c in b.filter(Geometry.commonPeers(p.cells | q.cells), p.digit) { out.insert(Candidate(c, p.digit)) }
            } else if !p.isGroup && !q.isGroup && p.cells == q.cells {
                let c = p.cells.first!
                for d in Mask.digits(b.candidates[c] & ~(Mask.bit(p.digit) | Mask.bit(q.digit))) { out.insert(Candidate(c, d)) }
            }
        }
        return out.subtracting(inLoop).sorted { ($0.cell, $0.digit) < ($1.cell, $1.digit) }
    }

    func conclusions(_ s: Int, _ e: Int, _ g: ChainGraph, _ b: Board) -> ([Candidate], [Candidate]) {
        let A = g.nodes[s], B = g.nodes[e]
        if s == e {
            // s off => ... => s on: s must be true.
            return ([], [Candidate(A.cells.first!, A.digit)])
        }
        if A.digit == B.digit {
            let targets = Geometry.commonPeers(A.cells | B.cells)
            return (b.filter(targets, A.digit).map { Candidate($0, A.digit) }, [])
        }
        guard !A.isGroup, !B.isGroup else { return ([], []) }
        let a = A.cells.first!, c = B.cells.first!
        if a == c {
            let keep = Mask.bit(A.digit) | Mask.bit(B.digit)
            return (Mask.digits(b.candidates[a] & ~keep).map { Candidate(a, $0) }, [])
        }
        if Geometry.sees(a, c) {
            var e: [Candidate] = []
            if b.has(a, B.digit) { e.append(Candidate(a, B.digit)) }
            if b.has(c, A.digit) { e.append(Candidate(c, A.digit)) }
            return (e, [])
        }
        return ([], [])
    }

    func makeStep(_ path: [Int], _ g: ChainGraph, _ b: Board, _ elims: [Candidate], _ places: [Candidate], loop: Bool = false) -> Step? {
        var hl: [Highlight] = []
        var links: [ChainLink] = []
        var text = ""
        for (i, st) in path.enumerated() {
            let node = g.nodes[st >> 1]
            let on = st & 1 == 1
            for c in node.cells { hl.append(Highlight(c, node.digit, on ? .chainOn : .chainOff)) }
            if i > 0 {
                let prev = g.nodes[path[i - 1] >> 1]
                let strong = on // arriving at an "on" node means we used a strong link
                links.append(ChainLink(from: prev.cells.map { Candidate($0, prev.digit) },
                                       to: node.cells.map { Candidate($0, node.digit) }, isStrong: strong))
                text += strong ? " = " : " - "
            }
            text += "(\(node.digit))\(Geometry.cellsName(node.cells))"
        }
        // Name refinement: the generic AIC mode reports chains that happen to be simpler as AIC anyway.
        if loop {
            let first = g.nodes[path[0] >> 1], last = g.nodes[path[path.count - 1] >> 1]
            links.append(ChainLink(from: last.cells.map { Candidate($0, last.digit) }, to: first.cells.map { Candidate($0, first.digit) }, isStrong: false))
            text += " - (\(first.digit))\(Geometry.cellsName(first.cells))"
            return Step(technique, eliminations: elims, highlights: hl, links: links, complexity: path.count + 1,
                        explanation: "Continuous Nice Loop: \(text). The loop closes on itself, so every weak link in it behaves like a strong one (exactly one end is true): \(describeEliminations(elims)).")
        }
        let what = places.isEmpty ? describeEliminations(elims) : "place " + places.map(\.description).joined(separator: ", ")
        return Step(technique, placements: places, eliminations: elims, highlights: hl, links: links,
                    complexity: path.count,
                    explanation: "\(technique.name): \(text). If the first candidate is false, the chain forces the last one true, so one of the two ends is true: \(what).")
    }
}

/// Graph of chain nodes (single candidates and box/line groups) with strong and weak links.
struct ChainGraph {
    struct Node: Hashable {
        var cells: CellSet
        var digit: Int
        var isGroup: Bool
    }
    struct Key: Hashable { var cells: CellSet; var digit: Int }

    let board: Board
    var nodes: [Node] = []
    var index: [Key: Int] = [:]
    var strong: [[Int]] = []
    var weak: [[Int]] = []

    init(_ b: Board, mode: ChainStrategy.Mode, digit: Int?) {
        board = b
        let bivalueOnly = mode == .xy || mode == .remotePair
        func allowed(_ d: Int) -> Bool { digit == nil || digit == d }

        for c in 0..<81 where b.isEmpty(c) {
            if bivalueOnly && b.candidates[c].nonzeroBitCount != 2 { continue }
            for d in Mask.digits(b.candidates[c]) where allowed(d) {
                add(Node(cells: CellSet([c]), digit: d, isGroup: false))
            }
        }
        if mode == .grouped {
            for box in 0..<9 {
                for line in 0..<18 {
                    let seg = Geometry.houseSets[18 + box] & Geometry.houseSets[line]
                    guard seg.count == 3 else { continue }
                    for d in 1...9 {
                        let cs = b.filter(seg, d)
                        if cs.count >= 2 { add(Node(cells: cs, digit: d, isGroup: true)) }
                    }
                }
            }
        }
        strong = Array(repeating: [], count: nodes.count)
        weak = Array(repeating: [], count: nodes.count)

        func link(_ a: Int?, _ c: Int?) {
            guard let a, let c, a != c else { return }
            strong[a].append(c); strong[c].append(a)
        }
        // Strong links within houses.
        if !bivalueOnly {
            for h in 0..<27 {
                for d in 1...9 where allowed(d) {
                    let pos = b.filter(Geometry.houseSets[h], d)
                    if pos.count == 2 {
                        let p = pos.array
                        link(index[Key(cells: CellSet([p[0]]), digit: d)], index[Key(cells: CellSet([p[1]]), digit: d)])
                    } else if mode == .grouped && pos.count >= 3 {
                        // Partition the house's candidates into two box/line segments.
                        let partitions: [[CellSet]]
                        if h < 18 {
                            partitions = [(0..<9).map { pos & Geometry.houseSets[18 + $0] }]
                        } else {
                            partitions = [(0..<9).map { pos & Geometry.houseSets[$0] }, (0..<9).map { pos & Geometry.houseSets[9 + $0] }]
                        }
                        for parts in partitions {
                            let nonEmpty = parts.filter { !$0.isEmpty }
                            guard nonEmpty.count == 2 else { continue }
                            link(index[Key(cells: nonEmpty[0], digit: d)], index[Key(cells: nonEmpty[1], digit: d)])
                        }
                    }
                }
            }
        }
        // Strong links within bivalue cells.
        if digit == nil {
            for c in 0..<81 where b.candidates[c].nonzeroBitCount == 2 {
                let ds = Mask.digits(b.candidates[c])
                link(index[Key(cells: CellSet([c]), digit: ds[0])], index[Key(cells: CellSet([c]), digit: ds[1])])
            }
        }
        // Weak links: same digit, all cells mutually visible; or same cell (single nodes).
        var byDigit: [[Int]] = Array(repeating: [], count: 10)
        for (i, n) in nodes.enumerated() { byDigit[n.digit].append(i) }
        for (i, n) in nodes.enumerated() {
            let peers = Geometry.commonPeers(n.cells)
            for j in byDigit[n.digit] where j != i && nodes[j].cells.isSubset(of: peers) {
                weak[i].append(j)
            }
            if !n.isGroup && !bivalueOnly && digit == nil {
                let c = n.cells.first!
                for d in Mask.digits(b.candidates[c]) where d != n.digit {
                    if let j = index[Key(cells: n.cells, digit: d)] { weak[i].append(j) }
                }
            }
        }
    }

    mutating func add(_ n: Node) {
        let k = Key(cells: n.cells, digit: n.digit)
        guard index[k] == nil else { return }
        index[k] = nodes.count
        nodes.append(n)
    }
}
