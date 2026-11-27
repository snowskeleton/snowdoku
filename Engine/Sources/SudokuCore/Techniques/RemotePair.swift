/// Remote Pair, as coloring: bivalue cells holding the same two digits that see each other must
/// hold opposite digits, so a connected network of them splits into two colors, one all x and the
/// other all y. Any other cell that sees both colors sees an x and a y, and loses both digits.
///
/// One step per network, with every eliminating cell, so a drill or hint shows the whole move
/// rather than one chain through it.
struct RemotePair: Strategy {
    let technique = Technique.remotePair
    var ranked: Bool { true }
    /// Below four cells every elimination is already a naked pair's.
    static let minCells = 4

    func find(_ b: Board, _ out: inout StepCollector) {
        var byPair: [DigitMask: [Int]] = [:]
        for c in 0..<81 where b.isEmpty(c) && b.candidates[c].nonzeroBitCount == 2 {
            byPair[b.candidates[c], default: []].append(c)
        }
        for pair in byPair.keys.sorted() {
            let cells = byPair[pair]!
            guard cells.count >= Self.minCells else { continue }
            let digits = Mask.digits(pair)
            for net in networks(cells) where net.all.count >= Self.minCells {
                let targets = (b.cells(with: digits[0]) | b.cells(with: digits[1])) - net.all
                var elims: [Candidate] = []
                for c in targets where seesAny(c, net.colors[0]) && seesAny(c, net.colors[1]) {
                    for d in digits where b.has(c, d) { elims.append(Candidate(c, d)) }
                }
                guard !elims.isEmpty else { continue }
                out.add(step(net, digits, elims))
                if out.done { return }
            }
        }
    }

    struct Network {
        var colors: [CellSet] = [CellSet(), CellSet()]
        /// Spanning-tree edges, for drawing.
        var edges: [(Int, Int)] = []
        var all: CellSet { colors[0] | colors[1] }
    }

    /// Connected components of `cells` under "sees", two-colored. A component with two same-colored
    /// cells seeing each other is a contradiction (wrong notes), not a remote pair, so it's dropped.
    func networks(_ cells: [Int]) -> [Network] {
        let set = CellSet(cells)
        var color: [Int: Int] = [:]
        var result: [Network] = []
        for start in cells where color[start] == nil {
            var net = Network()
            var stack = [start]
            color[start] = 0
            var consistent = true
            while let c = stack.popLast() {
                net.colors[color[c]!].insert(c)
                for n in Geometry.peerSets[c] & set {
                    if let k = color[n] {
                        if k == color[c]! { consistent = false }
                    } else {
                        color[n] = 1 - color[c]!
                        net.edges.append((c, n))
                        stack.append(n)
                    }
                }
            }
            if consistent { result.append(net) }
        }
        return result
    }

    func step(_ net: Network, _ digits: [Int], _ elims: [Candidate]) -> Step {
        let (x, y) = (digits[0], digits[1])
        var hl: [Highlight] = []
        for (k, role) in [(0, Highlight.Role.colorA), (1, .colorB)] {
            for c in net.colors[k] { hl.append(Highlight(c, x, role)); hl.append(Highlight(c, y, role)) }
        }
        let links = net.edges.map { a, b in
            ChainLink(from: [Candidate(a, x), Candidate(a, y)], to: [Candidate(b, x), Candidate(b, y)], isStrong: false)
        }
        let a = Geometry.cellsName(net.colors[0].array), bName = Geometry.cellsName(net.colors[1].array)
        let text = "Remote Pair on \(x)/\(y): every cell in \(a) and \(bName) holds only \(x) and \(y), and they're linked by seeing each other. "
            + "Linked cells must hold opposite digits, so \(a) are all one digit and \(bName) all the other. "
            + "A cell that sees one of each sees both \(x) and \(y): \(describeEliminations(elims))."
        return Step(technique, eliminations: elims, highlights: hl, links: links, complexity: net.all.count, explanation: text)
    }
}
