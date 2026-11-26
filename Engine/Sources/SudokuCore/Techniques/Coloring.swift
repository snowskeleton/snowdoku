/// Connected components of a digit's strong-link graph, two-colored.
struct ColorCluster {
    var colors: [CellSet] = [CellSet(), CellSet()]
    var all: CellSet { colors[0] | colors[1] }
}

func colorClusters(_ b: Board, _ d: Int) -> [ColorCluster] {
    var adj: [Int: [Int]] = [:]
    for l in strongLinks(b, d) {
        adj[l.a, default: []].append(l.b)
        adj[l.b, default: []].append(l.a)
    }
    var color: [Int: Int] = [:]
    var clusters: [ColorCluster] = []
    for start in adj.keys.sorted() where color[start] == nil {
        var cl = ColorCluster()
        var stack = [start]
        color[start] = 0
        while let c = stack.popLast() {
            cl.colors[color[c]!].insert(c)
            for n in adj[c]! where color[n] == nil {
                color[n] = 1 - color[c]!
                stack.append(n)
            }
        }
        if cl.all.count >= 3 { clusters.append(cl) }
    }
    return clusters
}

func seesAny(_ c: Int, _ set: CellSet) -> Bool { !(Geometry.peerSets[c] & set).isEmpty }

struct SimpleColoring: Strategy {
    let technique = Technique.simpleColoring
    func find(_ b: Board, _ out: inout StepCollector) {
        for d in 1...9 {
            for cl in colorClusters(b, d) {
                let hl = cl.colors[0].map { Highlight($0, d, .colorA) } + cl.colors[1].map { Highlight($0, d, .colorB) }
                // Color wrap: two cells of the same color see each other -> that color is false.
                for k in 0..<2 {
                    if cl.colors[k].contains(where: { seesAny($0, cl.colors[k]) }) {
                        let elims = cl.colors[k].map { Candidate($0, d) }
                        out.add(Step(technique, eliminations: elims, highlights: hl,
                                     explanation: "Simple Coloring on \(d): two cells of the same color see each other, so that whole color is false: \(describeEliminations(elims))."))
                        if out.done { return }
                    }
                }
                // Color trap: a cell seeing both colors.
                let targets = b.cells(with: d) - cl.all
                let elims = targets.filter { seesAny($0, cl.colors[0]) && seesAny($0, cl.colors[1]) }.map { Candidate($0, d) }
                if !elims.isEmpty {
                    out.add(Step(technique, eliminations: elims, highlights: hl,
                                 explanation: "Simple Coloring on \(d): following the strong links, one color must be true. Cells that see both colors can't be \(d): \(describeEliminations(elims))."))
                    if out.done { return }
                }
            }
        }
    }
}

struct MultiColoring: Strategy {
    let technique = Technique.multiColoring
    func find(_ b: Board, _ out: inout StepCollector) {
        for d in 1...9 {
            let clusters = colorClusters(b, d)
            guard clusters.count >= 2 else { continue }
            for i in 0..<clusters.count {
                for j in 0..<clusters.count where i != j {
                    let A = clusters[i], B = clusters[j]
                    let hl = A.colors[0].map { Highlight($0, d, .colorA) } + A.colors[1].map { Highlight($0, d, .colorB) }
                        + B.colors[0].map { Highlight($0, d, .colorC) } + B.colors[1].map { Highlight($0, d, .colorD) }
                    for ai in 0..<2 {
                        // Type 2: a color of A sees both colors of B -> it is false.
                        if A.colors[ai].contains(where: { seesAny($0, B.colors[0]) }) && A.colors[ai].contains(where: { seesAny($0, B.colors[1]) }) {
                            // Stronger form: one cell must see both; weaker (color-level) is also valid since one B color is true.
                            let elims = A.colors[ai].map { Candidate($0, d) }
                            out.add(Step(technique, eliminations: elims, highlights: hl,
                                         explanation: "Multi-Coloring on \(d): one color of the first cluster sees both colors of the second cluster, so it can't be true: \(describeEliminations(elims))."))
                            if out.done { return }
                        }
                        for bj in 0..<2 where A.colors[ai].contains(where: { seesAny($0, B.colors[bj]) }) {
                            // A[ai] and B[bj] can't both be true -> A[1-ai] or B[1-bj] is true.
                            let x = A.colors[1 - ai], y = B.colors[1 - bj]
                            let targets = b.cells(with: d) - A.all - B.all
                            let elims = targets.filter { seesAny($0, x) && seesAny($0, y) }.map { Candidate($0, d) }
                            guard !elims.isEmpty else { continue }
                            out.add(Step(technique, eliminations: elims, highlights: hl,
                                         explanation: "Multi-Coloring on \(d): two clusters touch, so at least one of their opposite colors is true. Cells seeing both of those colors can't be \(d): \(describeEliminations(elims))."))
                            if out.done { return }
                        }
                    }
                }
            }
        }
    }
}
