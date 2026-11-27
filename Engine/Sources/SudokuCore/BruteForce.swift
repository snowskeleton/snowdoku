/// Fast backtracking solver. Used to verify uniqueness, find solutions and build random grids.
/// It never explains anything; that is `HumanSolver`'s job.
public enum BruteForce {
    public enum Result: Equatable, Sendable {
        case none
        case unique(Grid)
        case multiple
    }

    public static func analyze(_ grid: Grid) -> Result {
        var first: [UInt8]?
        switch SolutionCounter.count(grid.cells, limit: 2, first: &first) {
        case 0: return .none
        case 1: return .unique(Grid(cells: first!))
        default: return .multiple
        }
    }

    public static func countSolutions(_ grid: Grid, limit: Int = 2) -> Int {
        var first: [UInt8]?
        return SolutionCounter.count(grid.cells, limit: limit, first: &first)
    }

    public static func hasUniqueSolution(_ grid: Grid) -> Bool { countSolutions(grid, limit: 2) == 1 }

    public static func solution(_ grid: Grid) -> Grid? {
        var first: [UInt8]?
        _ = SolutionCounter.count(grid.cells, limit: 1, first: &first)
        return first.map { Grid(cells: $0) }
    }

    /// Whether `puzzle` has a solution other than `solution`, given that filling `cells` back in from
    /// `solution` leaves a puzzle whose only solution is `solution` (as when the generator removes
    /// clues from a unique puzzle). Any other solution must then differ from `solution` in one of
    /// `cells`, so this searches for exactly that, which is much cheaper than counting solutions.
    public static func hasOtherSolution(_ puzzle: Grid, than solution: Grid, differingIn cells: [Int]) -> Bool {
        var first: [UInt8]?
        var known = puzzle.cells
        for (i, c) in cells.enumerated() {
            // Earlier cells already got their own search, so here they keep their solution value.
            if i > 0 { known[cells[i - 1]] = UInt8(solution[cells[i - 1]]) }
            if SolutionCounter.count(known, limit: 1, first: &first, forbid: c, digit: solution[c]) > 0 { return true }
        }
        return false
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

/// Counts solutions (up to a limit) with a depth-first search on raw buffers: the house masks, the
/// grid and a list of the empty cells, so the search allocates nothing. Each node fills the empty
/// cell with the fewest candidates. Used for every uniqueness check, so it's the generator's hot loop.
struct SolutionCounter {
    let cells: UnsafeMutablePointer<UInt8>   // 81
    let houses: UnsafeMutablePointer<UInt16> // 27 used-digit masks: rows, columns, boxes
    let empties: UnsafeMutablePointer<Int>   // empty cells; the first n are still unfilled
    let rowOf: UnsafeMutablePointer<Int>, colOf: UnsafeMutablePointer<Int>, boxOf: UnsafeMutablePointer<Int>
    let limit: Int
    let forbidCell: Int, forbidMask: UInt16
    var count = 0
    var first: [UInt8]?

    static let geometry: [Int] = Geometry.rowOf + Geometry.colOf.map { $0 + 9 } + Geometry.boxOf.map { $0 + 18 }

    /// Number of solutions of `grid`, stopping at `limit`; `first` receives the first one found.
    /// With `forbid`, that cell may not hold `digit`.
    static func count(_ grid: [UInt8], limit: Int, first: inout [UInt8]?, forbid: Int = -1, digit: Int = 0) -> Int {
        let buffer = UnsafeMutablePointer<Int>.allocate(capacity: 81 * 4)
        let cells = UnsafeMutablePointer<UInt8>.allocate(capacity: 81)
        let houses = UnsafeMutablePointer<UInt16>.allocate(capacity: 27)
        defer { buffer.deallocate(); cells.deallocate(); houses.deallocate() }
        geometry.withUnsafeBufferPointer { buffer.initialize(from: $0.baseAddress!, count: 243) }
        houses.initialize(repeating: 0, count: 27)
        let empties = buffer + 243
        var n = 0
        for i in 0..<81 {
            let v = grid[i]
            cells[i] = v
            if v == 0 { empties[n] = i; n += 1; continue }
            let b = UInt16(1) << UInt16(v - 1)
            let r = buffer[i], c = buffer[81 + i], x = buffer[162 + i]
            if (houses[r] | houses[c] | houses[x]) & b != 0 { return 0 }
            houses[r] |= b; houses[c] |= b; houses[x] |= b
        }
        var s = SolutionCounter(cells: cells, houses: houses, empties: empties,
                                rowOf: buffer, colOf: buffer + 81, boxOf: buffer + 162, limit: limit,
                                forbidCell: forbid, forbidMask: forbid >= 0 ? Mask.bit(digit) : 0)
        _ = s.search(n)
        first = s.first
        return s.count
    }

    /// Returns true when the limit is reached and the search should stop.
    mutating func search(_ n: Int) -> Bool {
        if n == 0 {
            count += 1
            if first == nil { first = Array(UnsafeBufferPointer(start: cells, count: 81)) }
            return count >= limit
        }
        var bestK = 0, bestCount = 10
        var bestMask: UInt16 = 0
        for k in 0..<n {
            let c = empties[k]
            var m = ~(houses[rowOf[c]] | houses[colOf[c]] | houses[boxOf[c]]) & 0x1FF
            if c == forbidCell { m &= ~forbidMask }
            let cnt = m.nonzeroBitCount
            if cnt < bestCount {
                if cnt == 0 { return false }
                bestK = k; bestCount = cnt; bestMask = m
                if cnt == 1 { break }
            }
        }
        // Move the chosen cell past the unfilled part; the set of the first n-1 stays the same.
        let cell = empties[bestK]
        empties[bestK] = empties[n - 1]
        empties[n - 1] = cell
        let r = rowOf[cell], c = colOf[cell], x = boxOf[cell]
        var m = bestMask
        while m != 0 {
            let b = m & (0 &- m)
            m &= m &- 1
            cells[cell] = UInt8(b.trailingZeroBitCount + 1)
            houses[r] |= b; houses[c] |= b; houses[x] |= b
            let stop = search(n - 1)
            houses[r] &= ~b; houses[c] &= ~b; houses[x] &= ~b
            if stop { cells[cell] = 0; return true }
        }
        cells[cell] = 0
        return false
    }
}
