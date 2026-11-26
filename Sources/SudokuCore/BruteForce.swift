/// Fast backtracking solver. Used to verify uniqueness, find solutions and build random grids.
/// It never explains anything; that is `HumanSolver`'s job.
public enum BruteForce {
    public enum Result: Equatable, Sendable {
        case none
        case unique(Grid)
        case multiple
    }

    public static func analyze(_ grid: Grid) -> Result {
        var s = DFS<SplitMix64>(cells: grid.cells, limit: 2, rng: nil)
        guard s.valid else { return .none }
        s.search()
        switch s.count {
        case 0: return .none
        case 1: return .unique(Grid(cells: s.first!))
        default: return .multiple
        }
    }

    public static func countSolutions(_ grid: Grid, limit: Int = 2) -> Int {
        var s = DFS<SplitMix64>(cells: grid.cells, limit: limit, rng: nil)
        guard s.valid else { return 0 }
        s.search()
        return s.count
    }

    public static func hasUniqueSolution(_ grid: Grid) -> Bool { countSolutions(grid, limit: 2) == 1 }

    public static func solution(_ grid: Grid) -> Grid? {
        var s = DFS<SplitMix64>(cells: grid.cells, limit: 1, rng: nil)
        guard s.valid else { return nil }
        s.search()
        return s.first.map { Grid(cells: $0) }
    }

    /// A uniformly shuffled, completely filled valid grid.
    public static func randomFilledGrid<R: RandomNumberGenerator>(using rng: inout R) -> Grid {
        var s = DFS<R>(cells: Array(repeating: 0, count: 81), limit: 1, rng: rng)
        s.search()
        rng = s.rng!
        return Grid(cells: s.first!)
    }
}

struct DFS<R: RandomNumberGenerator> {
    var cells: [UInt8]
    var rows = [UInt16](repeating: 0, count: 9)
    var cols = [UInt16](repeating: 0, count: 9)
    var boxes = [UInt16](repeating: 0, count: 9)
    var count = 0
    let limit: Int
    var first: [UInt8]?
    var rng: R?
    var valid = true
    let rowOf = Geometry.rowOf, colOf = Geometry.colOf, boxOf = Geometry.boxOf

    init(cells: [UInt8], limit: Int, rng: R?) {
        self.cells = cells
        self.limit = limit
        self.rng = rng
        for i in 0..<81 where cells[i] != 0 {
            let b = UInt16(1) << UInt16(cells[i] - 1)
            let r = rowOf[i], c = colOf[i], x = boxOf[i]
            if (rows[r] | cols[c] | boxes[x]) & b != 0 { valid = false }
            rows[r] |= b; cols[c] |= b; boxes[x] |= b
        }
    }

    mutating func search() {
        var best = -1, bestCount = 10
        var bestMask: UInt16 = 0
        for i in 0..<81 where cells[i] == 0 {
            let m = ~(rows[rowOf[i]] | cols[colOf[i]] | boxes[boxOf[i]]) & 0x1FF
            let n = m.nonzeroBitCount
            if n < bestCount {
                best = i; bestCount = n; bestMask = m
                if n <= 1 { break }
            }
        }
        if best < 0 {
            count += 1
            if first == nil { first = cells }
            return
        }
        if bestCount == 0 { return }
        var digits = Mask.digits(bestMask)
        if rng != nil { digits.shuffle(using: &rng!) }
        let r = rowOf[best], c = colOf[best], x = boxOf[best]
        for d in digits {
            let b = UInt16(1) << UInt16(d - 1)
            cells[best] = UInt8(d)
            rows[r] |= b; cols[c] |= b; boxes[x] |= b
            search()
            rows[r] &= ~b; cols[c] &= ~b; boxes[x] &= ~b
            cells[best] = 0
            if count >= limit { return }
        }
    }
}
