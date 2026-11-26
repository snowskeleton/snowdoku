/// Tabling: the implication tables behind forcing chains and nets (the method HoDoKu uses, after
/// Trebor's tables). For an assumed literal ("r1c1 is 5" or "r1c1 isn't 5") we derive everything
/// that follows, and remember *why* each conclusion follows, so a step can show its chains.
///
/// A literal is a candidate that is on (the cell holds the digit) or off (it doesn't).
///
/// - `on` always implies `off` for the cell's other candidates and the digit's other cells in each house.
/// - `off` implies `on` when it leaves a cell or a house with one place for a digit.
///
/// In **chain** mode, `off` implies `on` only across a strong link of the starting position
/// (a bivalue cell or a house with two places), so every conclusion has one premise and the
/// reasoning is a simple chain. In **net** mode, `off` → `on` may rest on several earlier
/// conclusions at once (a cell emptied by three different eliminations), which is a net.
struct Literal: Hashable, Sendable, CustomStringConvertible {
    var raw: Int

    init(raw: Int) { self.raw = raw }
    init(_ cell: Int, _ digit: Int, on: Bool) { raw = (cell * 9 + digit - 1) * 2 + (on ? 1 : 0) }

    var cell: Int { raw / 18 }
    var digit: Int { (raw / 2) % 9 + 1 }
    var on: Bool { raw & 1 == 1 }
    var negated: Literal { Literal(raw: raw ^ 1) }
    var candidate: Candidate { Candidate(cell, digit) }

    var description: String { "\(Geometry.cellName(cell))\(on ? "=" : "≠")\(digit)" }

    static let count = 81 * 9 * 2
}

/// Everything that follows from one assumption, with the premises of each conclusion.
struct ImplicationTable {
    let start: Literal
    /// Literals in the order they were derived; `order[0]` is the assumption itself.
    private(set) var order: [Literal] = []
    /// For each derived literal, its position in `order` (or -1).
    private var rank: [Int32]
    /// Premises of each derived literal (indices into `order`), stored flat.
    private var premiseStart: [Int32]
    private var premiseCount: [UInt8]
    private var premises: [Int32] = []
    /// Literals that can't all hold together. Set when the assumption leads to a contradiction.
    private(set) var conflict: [Literal]?
    /// What the contradiction is, in words ("r4c4 would be both 2 and not 2").
    private(set) var conflictText = ""

    func has(_ l: Literal) -> Bool { rank[l.raw] >= 0 }

    /// Each cell's index within each of its houses (row, column, box).
    static let indexInHouse: [[Int]] = (0..<81).map { c in Geometry.housesOfCell[c].map { Geometry.houses[$0].firstIndex(of: c)! } }

    /// Candidate positions per (house, digit) of a board: `masks[h * 9 + d - 1]`.
    static func houseMasks(_ b: Board) -> [UInt16] {
        var m = [UInt16](repeating: 0, count: 27 * 9)
        for h in 0..<27 { for d in 1...9 { m[h * 9 + d - 1] = b.positionMask(d, h) } }
        return m
    }

    init(_ b: Board, assume start: Literal, net: Bool, houseMasks: [UInt16]? = nil) {
        self.start = start
        rank = Array(repeating: -1, count: Literal.count)
        premiseStart = Array(repeating: 0, count: Literal.count)
        premiseCount = Array(repeating: 0, count: Literal.count)
        depth = Array(repeating: 0, count: Literal.count)
        order.reserveCapacity(256)
        premises.reserveCapacity(512)
        // Remaining candidates per cell and positions per (house, digit), given the offs so far.
        let allPos = houseMasks ?? Self.houseMasks(b)
        var cellLeft = b.candidates
        var houseLeft = allPos

        rank[start.raw] = 0
        order.append(start)
        var head = 0
        while head < order.count && conflict == nil {
            let l = order[head]; head += 1
            let c = l.cell, d = l.digit
            if l.on {
                var m = b.candidates[c] & ~Mask.bit(d)
                while m != 0 {
                    derive(Literal(c, m.trailingZeroBitCount + 1, on: false), l)
                    m &= m &- 1
                }
                let bit = Mask.bit(d)
                for p in Geometry.peers[c] where b.candidates[p] & bit != 0 { derive(Literal(p, d, on: false), l) }
                continue
            }
            // l is off: one fewer option for the cell and for the digit in each of its houses.
            cellLeft[c] &= ~Mask.bit(d)
            let left = cellLeft[c]
            if left == 0 {
                fail(Mask.digits(b.candidates[c]).map { Literal(c, $0, on: false) },
                     "every candidate of \(Geometry.cellName(c)) would be ruled out")
                break
            }
            if left.nonzeroBitCount == 1 && (net || b.candidates[c].nonzeroBitCount == 2) {
                let e = Mask.first(left)
                var m = b.candidates[c] & ~left
                var ps: [Literal] = []
                while m != 0 { ps.append(Literal(c, m.trailingZeroBitCount + 1, on: false)); m &= m &- 1 }
                derive(Literal(c, e, on: true), ps)
            }
            let houses = Geometry.housesOfCell[c], idx = Self.indexInHouse[c]
            for i in 0..<3 {
                let h = houses[i], k = h * 9 + d - 1
                houseLeft[k] &= ~(1 << UInt16(idx[i]))
                let pos = houseLeft[k], all = allPos[k]
                let cells = Geometry.houses[h]
                if pos == 0 {
                    fail(Mask.indices(all).map { Literal(cells[$0], d, on: false) },
                         "\(d) would have nowhere to go in \(Geometry.houseName(h))")
                    break
                }
                if pos.nonzeroBitCount == 1 && (net || all.nonzeroBitCount == 2) {
                    let p = cells[pos.trailingZeroBitCount]
                    guard rank[Literal(p, d, on: true).raw] < 0 else { continue }
                    var m = all & ~pos
                    var ps: [Literal] = []
                    while m != 0 { ps.append(Literal(cells[m.trailingZeroBitCount], d, on: false)); m &= m &- 1 }
                    derive(Literal(p, d, on: true), ps)
                }
            }
        }
    }

    /// Depth of each derived literal: the longest premise path back to the assumption.
    private var depth: [UInt16]

    /// How many inferences deep `l` is (a chain's length; a net's longest strand).
    func depthOf(_ l: Literal) -> Int { Int(depth[l.raw]) }

    private mutating func derive(_ l: Literal, _ premise: Literal) {
        guard conflict == nil, rank[l.raw] < 0 else { return }
        rank[l.raw] = Int32(order.count)
        premiseStart[l.raw] = Int32(premises.count)
        premiseCount[l.raw] = 1
        premises.append(rank[premise.raw])
        depth[l.raw] = depth[premise.raw] + 1
        order.append(l)
        checkNegation(l)
    }

    private mutating func derive(_ l: Literal, _ cause: [Literal]) {
        guard conflict == nil, rank[l.raw] < 0 else { return }
        rank[l.raw] = Int32(order.count)
        premiseStart[l.raw] = Int32(premises.count)
        premiseCount[l.raw] = UInt8(cause.count)
        var dp: UInt16 = 0
        for p in cause { premises.append(rank[p.raw]); dp = max(dp, depth[p.raw]) }
        depth[l.raw] = dp + 1
        order.append(l)
        checkNegation(l)
    }

    private mutating func checkNegation(_ l: Literal) {
        if rank[l.negated.raw] >= 0 {
            let x = l.on ? l : l.negated
            fail([l, l.negated], "\(Geometry.cellName(x.cell)) would be both \(x.digit) and not \(x.digit)")
        }
    }

    private mutating func fail(_ lits: [Literal], _ text: String) {
        conflict = lits
        conflictText = text
    }

    func premisesOf(_ l: Literal) -> [Literal] {
        let s = Int(premiseStart[l.raw])
        return (0..<Int(premiseCount[l.raw])).map { order[Int(premises[s + $0])] }
    }

    /// The derivation of `targets` from the assumption: every literal needed, in derivation order.
    /// In chain mode this is a single path per target.
    func derivation(of targets: [Literal]) -> [Literal] {
        var need = Set<Int>()
        var stack = targets.filter(has)
        while let l = stack.popLast() {
            guard need.insert(l.raw).inserted else { continue }
            stack += premisesOf(l)
        }
        return need.map { Literal(raw: $0) }.sorted { rank[$0.raw] < rank[$1.raw] }
    }

    /// The derivation as text: "r1c1=5 → r1c3≠5 → r1c3=2" for a chain; nets list the
    /// premises of each multi-premise step in brackets.
    func describe(_ lits: [Literal], limit: Int = 16) -> String {
        guard let first = lits.first else { return "" }
        if lits.contains(where: { premisesOf($0).count > 1 }) { return describeNet(lits) }
        var parts: [String] = []
        var prev = first
        for l in lits.dropFirst() {
            let ps = premisesOf(l)
            if ps.count == 1 && ps[0] == prev { parts.append(" → \(l)") }
            else if ps.count == 1 { parts.append("; \(ps[0]) → \(l)") }
            else { parts.append("; (\(ps.map(\.description).joined(separator: ", "))) → \(l)") }
            prev = l
        }
        if parts.count > limit {
            parts = Array(parts.prefix(limit - 1)) + [" … (\(parts.count - limit) more steps) …", parts.last!]
        }
        return first.description + parts.joined()
    }

    /// A net is too bushy to spell out link by link, so it reads as the cells it fills in, in
    /// order, ending with the conclusion: "r4c1=2 → (r2c5=2, r2c7=1, r2c9=6, …) → r4c8=6".
    private func describeNet(_ lits: [Literal], limit: Int = 10) -> String {
        guard let first = lits.first, let last = lits.last else { return "" }
        var placed = lits.dropFirst().filter { $0.on && $0 != last }.map(\.description)
        if placed.count > limit { placed = Array(placed.prefix(limit - 1)) + ["… (\(placed.count - limit + 1) more)"] }
        let middle = placed.isEmpty ? "" : " → (" + placed.joined(separator: ", ") + ")"
        return "\(first)\(middle) → \(last)"
    }

    /// Links for drawing: one per premise → conclusion pair. "Strong" when it proves an `on`.
    func links(_ lits: [Literal]) -> [ChainLink] {
        lits.flatMap { l in premisesOf(l).map { p in ChainLink(from: [p.candidate], to: [l.candidate], isStrong: l.on) } }
    }

    static func highlights(_ lits: [Literal]) -> [Highlight] {
        lits.map { Highlight($0.cell, $0.digit, $0.on ? .chainOn : .chainOff) }
    }

    /// Number of inferences in a derivation (its length, for ranking).
    static func length(_ lits: [Literal]) -> Int { max(0, lits.count - 1) }
}

/// Lazily built tables for one board, shared by the forcing strategies of one search.
struct TableCache {
    let board: Board
    let net: Bool
    private var tables = [ImplicationTable?](repeating: nil, count: Literal.count)

    private let houseMasks: [UInt16]

    init(_ b: Board, net: Bool) { board = b; self.net = net; houseMasks = ImplicationTable.houseMasks(b) }

    mutating func table(_ l: Literal) -> ImplicationTable {
        if let t = tables[l.raw] { return t }
        let t = ImplicationTable(board, assume: l, net: net, houseMasks: houseMasks)
        tables[l.raw] = t
        return t
    }
}
