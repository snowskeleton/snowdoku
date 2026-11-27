/// Candidate-level board state used by the human-style solver.
public struct Board: Hashable, Sendable {
    public private(set) var values: [UInt8]
    /// Candidate masks; always 0 for solved cells.
    public internal(set) var candidates: [DigitMask]
    public let givens: CellSet
    /// For each digit (index 1-9), the cells that hold it as a candidate. Kept in step with
    /// `candidates` so house and digit lookups are a few bit operations instead of cell scans.
    public private(set) var digitCells: [CellSet]

    /// Builds a board from a puzzle with all candidates computed from the givens.
    public init(_ grid: Grid) {
        values = grid.cells
        givens = CellSet((0..<81).filter { grid.cells[$0] != 0 })
        candidates = Array(repeating: 0, count: 81)
        for c in 0..<81 where values[c] == 0 {
            var m = Mask.all
            for p in Geometry.peers[c] where values[p] != 0 { m &= ~Mask.bit(Int(values[p])) }
            candidates[c] = m
        }
        digitCells = Board.digitCells(candidates)
    }

    /// Builds a board from an arbitrary state (e.g. the player's pencil marks).
    public init(values: [UInt8], candidates: [DigitMask], givens: CellSet) {
        self.values = values
        self.givens = givens
        self.candidates = (0..<81).map { values[$0] == 0 ? candidates[$0] : 0 }
        digitCells = Board.digitCells(self.candidates)
    }

    private static func digitCells(_ candidates: [DigitMask]) -> [CellSet] {
        var planes = [CellSet](repeating: CellSet(), count: 10)
        for c in 0..<81 {
            var m = candidates[c]
            while m != 0 {
                planes[m.trailingZeroBitCount + 1].insert(c)
                m &= m &- 1
            }
        }
        return planes
    }

    @inline(__always) public func value(_ c: Int) -> Int { Int(values[c]) }
    @inline(__always) public func has(_ c: Int, _ d: Int) -> Bool { candidates[c] & Mask.bit(d) != 0 }
    @inline(__always) public func isEmpty(_ c: Int) -> Bool { values[c] == 0 }

    public var grid: Grid { Grid(cells: values) }
    public var isSolved: Bool { !values.contains(0) }
    public var emptyCells: [Int] { (0..<81).filter { values[$0] == 0 } }

    /// Places a digit and removes it from all peers' candidates.
    public mutating func place(_ c: Int, _ d: Int) {
        values[c] = UInt8(d)
        var m = candidates[c]
        while m != 0 {
            digitCells[m.trailingZeroBitCount + 1].remove(c)
            m &= m &- 1
        }
        candidates[c] = 0
        let b = ~Mask.bit(d)
        for p in Geometry.peers[c] { candidates[p] &= b }
        digitCells[d] = digitCells[d] - Geometry.peerSets[c]
    }

    @discardableResult
    public mutating func eliminate(_ c: Int, _ d: Int) -> Bool {
        let b = Mask.bit(d)
        guard candidates[c] & b != 0 else { return false }
        candidates[c] &= ~b
        digitCells[d].remove(c)
        return true
    }

    public mutating func apply(_ step: Step) {
        for e in step.eliminations { eliminate(e.cell, e.digit) }
        for p in step.placements where values[p.cell] == 0 { place(p.cell, p.digit) }
    }

    /// Cells in `house` that have `d` as a candidate.
    public func positions(_ d: Int, _ house: Int) -> [Int] {
        let cells = Geometry.houses[house]
        var m = positionMask(d, house), out: [Int] = []
        while m != 0 {
            out.append(cells[m.trailingZeroBitCount])
            m &= m &- 1
        }
        return out
    }

    /// Bit k set when the k-th cell of `house` has candidate `d`.
    public func positionMask(_ d: Int, _ house: Int) -> UInt16 {
        let p = digitCells[d]
        if house < 9 { return UInt16(p.bits(house * 9, 9)) }
        if house < 18 {
            let col = house - 9
            var m: UInt16 = 0
            for k in 0..<9 where p.contains(k * 9 + col) { m |= 1 << UInt16(k) }
            return m
        }
        let box = house - 18, first = (box / 3) * 27 + (box % 3) * 3
        return UInt16(p.bits(first, 3) | p.bits(first + 9, 3) << 3 | p.bits(first + 18, 3) << 6)
    }

    public func isPlaced(_ d: Int, in house: Int) -> Bool {
        Geometry.houses[house].contains { values[$0] == UInt8(d) }
    }

    /// All cells holding candidate `d`.
    public func cells(with d: Int) -> CellSet { digitCells[d] }

    /// Cells in `set` that hold candidate `d`.
    public func filter(_ set: CellSet, _ d: Int) -> CellSet { set & digitCells[d] }

    /// Union of candidates over the given cells.
    public func union<S: Sequence>(_ cells: S) -> DigitMask where S.Element == Int {
        cells.reduce(0) { $0 | candidates[$1] }
    }

    /// False when the state is obviously broken (an empty cell without candidates,
    /// a digit with nowhere to go in a house, or duplicate values).
    public var isConsistent: Bool {
        for c in 0..<81 where values[c] == 0 && candidates[c] == 0 { return false }
        for h in 0..<27 {
            var placed: DigitMask = 0, possible: DigitMask = 0
            for c in Geometry.houses[h] {
                if values[c] != 0 {
                    let b = Mask.bit(Int(values[c]))
                    if placed & b != 0 { return false }
                    placed |= b
                } else {
                    possible |= candidates[c]
                }
            }
            if placed | possible != Mask.all { return false }
        }
        return true
    }
}
