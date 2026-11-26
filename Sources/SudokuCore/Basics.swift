// Low-level primitives: digit masks, 81-bit cell sets, board geometry, RNG.

/// Bitmask of digits 1...9 (bit 0 = digit 1).
public typealias DigitMask = UInt16

public enum Mask {
    public static let all: DigitMask = 0x1FF

    @inline(__always) public static func bit(_ d: Int) -> DigitMask { 1 &<< DigitMask(d &- 1) }

    /// Digits (1-based) contained in the mask, ascending.
    public static func digits(_ m: DigitMask) -> [Int] {
        var r: [Int] = []
        var m = m
        while m != 0 {
            r.append(m.trailingZeroBitCount + 1)
            m &= m &- 1
        }
        return r
    }

    /// Zero-based bit indices contained in the mask, ascending.
    public static func indices(_ m: DigitMask) -> [Int] {
        var r: [Int] = []
        var m = m
        while m != 0 {
            r.append(m.trailingZeroBitCount)
            m &= m &- 1
        }
        return r
    }

    @inline(__always) public static func first(_ m: DigitMask) -> Int { m.trailingZeroBitCount + 1 }

    public static func from(_ digits: [Int]) -> DigitMask { digits.reduce(0) { $0 | bit($1) } }
}

/// A set of cells (0...80) stored as two 64-bit words.
public struct CellSet: Hashable, Sendable, Sequence, Codable {
    public var lo: UInt64 = 0
    public var hi: UInt64 = 0

    public init() {}
    public init<S: Sequence>(_ cells: S) where S.Element == Int {
        for c in cells { insert(c) }
    }

    @inline(__always) public func contains(_ c: Int) -> Bool {
        c < 64 ? (lo >> UInt64(c)) & 1 == 1 : (hi >> UInt64(c - 64)) & 1 == 1
    }
    @inline(__always) public mutating func insert(_ c: Int) {
        if c < 64 { lo |= 1 << UInt64(c) } else { hi |= 1 << UInt64(c - 64) }
    }
    @inline(__always) public mutating func remove(_ c: Int) {
        if c < 64 { lo &= ~(1 << UInt64(c)) } else { hi &= ~(1 << UInt64(c - 64)) }
    }
    public var isEmpty: Bool { lo == 0 && hi == 0 }
    public var count: Int { lo.nonzeroBitCount + hi.nonzeroBitCount }
    public var first: Int? {
        if lo != 0 { return lo.trailingZeroBitCount }
        if hi != 0 { return hi.trailingZeroBitCount + 64 }
        return nil
    }
    public var array: [Int] { Array(self) }

    public static func & (a: CellSet, b: CellSet) -> CellSet { var r = CellSet(); r.lo = a.lo & b.lo; r.hi = a.hi & b.hi; return r }
    public static func | (a: CellSet, b: CellSet) -> CellSet { var r = CellSet(); r.lo = a.lo | b.lo; r.hi = a.hi | b.hi; return r }
    public static func - (a: CellSet, b: CellSet) -> CellSet { var r = CellSet(); r.lo = a.lo & ~b.lo; r.hi = a.hi & ~b.hi; return r }
    public static func &= (a: inout CellSet, b: CellSet) { a = a & b }
    public static func |= (a: inout CellSet, b: CellSet) { a = a | b }

    public func isSubset(of o: CellSet) -> Bool { (self - o).isEmpty }
    public func isDisjoint(with o: CellSet) -> Bool { (self & o).isEmpty }

    public func makeIterator() -> Iterator { Iterator(lo: lo, hi: hi) }
    public struct Iterator: IteratorProtocol {
        var lo: UInt64, hi: UInt64
        public mutating func next() -> Int? {
            if lo != 0 { let t = lo.trailingZeroBitCount; lo &= lo &- 1; return t }
            if hi != 0 { let t = hi.trailingZeroBitCount; hi &= hi &- 1; return t + 64 }
            return nil
        }
    }
}

/// Static geometry of the 9x9 board. Houses 0-8 are rows, 9-17 columns, 18-26 boxes.
public enum Geometry {
    public static let rowOf: [Int] = (0..<81).map { $0 / 9 }
    public static let colOf: [Int] = (0..<81).map { $0 % 9 }
    public static let boxOf: [Int] = (0..<81).map { ($0 / 27) * 3 + ($0 % 9) / 3 }

    @inline(__always) public static func cell(_ r: Int, _ c: Int) -> Int { r * 9 + c }

    public static let houses: [[Int]] = {
        var h: [[Int]] = []
        for r in 0..<9 { h.append((0..<9).map { r * 9 + $0 }) }
        for c in 0..<9 { h.append((0..<9).map { $0 * 9 + c }) }
        for b in 0..<9 {
            let r0 = (b / 3) * 3, c0 = (b % 3) * 3
            h.append((0..<9).map { (r0 + $0 / 3) * 9 + c0 + $0 % 3 })
        }
        return h
    }()
    public static let houseSets: [CellSet] = houses.map { CellSet($0) }
    public static let housesOfCell: [[Int]] = (0..<81).map { [rowOf[$0], 9 + colOf[$0], 18 + boxOf[$0]] }
    public static let peers: [[Int]] = (0..<81).map { c in
        (0..<81).filter { $0 != c && (rowOf[$0] == rowOf[c] || colOf[$0] == colOf[c] || boxOf[$0] == boxOf[c]) }
    }
    public static let peerSets: [CellSet] = peers.map { CellSet($0) }

    @inline(__always) public static func sees(_ a: Int, _ b: Int) -> Bool {
        a != b && (rowOf[a] == rowOf[b] || colOf[a] == colOf[b] || boxOf[a] == boxOf[b])
    }

    /// Cells that see every cell in `cells` (never includes the cells themselves).
    public static func commonPeers(_ cells: CellSet) -> CellSet {
        var r = CellSet(); r.lo = ~0; r.hi = (1 << 17) - 1
        for c in cells { r &= peerSets[c] }
        return r
    }

    public enum HouseKind: Sendable { case row, column, box }
    public static func kind(_ h: Int) -> HouseKind { h < 9 ? .row : h < 18 ? .column : .box }

    public static func houseName(_ h: Int) -> String {
        switch kind(h) {
        case .row: return "row \(h + 1)"
        case .column: return "column \(h - 8)"
        case .box: return "box \(h - 17)"
        }
    }
    public static func cellName(_ c: Int) -> String { "r\(rowOf[c] + 1)c\(colOf[c] + 1)" }
    public static func cellsName<S: Sequence>(_ cells: S) -> String where S.Element == Int {
        cells.map(cellName).joined(separator: ",")
    }
    /// Houses that contain all of the given cells.
    public static func sharedHouses(_ cells: [Int]) -> [Int] {
        guard let f = cells.first else { return [] }
        return housesOfCell[f].filter { h in cells.allSatisfy { houseSets[h].contains($0) } }
    }
}

/// Calls `body` with each k-combination of 0..<n (as ascending indices). Return false to stop.
@discardableResult
func forEachCombination(_ n: Int, _ k: Int, _ body: ([Int]) -> Bool) -> Bool {
    guard k > 0, k <= n else { return true }
    var idx = Array(0..<k)
    while true {
        if !body(idx) { return false }
        var i = k - 1
        while i >= 0 && idx[i] == n - k + i { i -= 1 }
        if i < 0 { return true }
        idx[i] += 1
        var j = i + 1
        while j < k { idx[j] = idx[j - 1] + 1; j += 1 }
    }
}

/// Small, fast, seedable PRNG (SplitMix64) so daily puzzles and generation runs are reproducible.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    public var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
