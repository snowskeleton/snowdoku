/// A plain 9x9 grid of values (0 = empty). Used for puzzles and solutions.
public struct Grid: Hashable, Sendable, Codable, CustomStringConvertible {
    public var cells: [UInt8]

    public init() { cells = Array(repeating: 0, count: 81) }

    public init(cells: [UInt8]) {
        precondition(cells.count == 81)
        self.cells = cells
    }

    /// Parses an 81-character string. Digits 1-9 are values; `0` or `.` are empty.
    /// Whitespace and common separators (`|`, `-`, `+`) are ignored.
    public init?(_ string: String) {
        var c: [UInt8] = []
        c.reserveCapacity(81)
        for ch in string {
            if let v = ch.wholeNumberValue, (0...9).contains(v) { c.append(UInt8(v)) }
            else if ch == "." || ch == "_" { c.append(0) }
            else if ch.isWhitespace || "|-+".contains(ch) { continue }
            else { return nil }
        }
        guard c.count == 81 else { return nil }
        cells = c
    }

    public subscript(_ cell: Int) -> Int {
        get { Int(cells[cell]) }
        set { cells[cell] = UInt8(newValue) }
    }

    /// Compact 81-character form with `.` for empties.
    public var string: String { String(cells.map { $0 == 0 ? "." : Character(String($0)) }) }
    public var description: String { string }

    public var givenCount: Int { cells.reduce(0) { $0 + ($1 == 0 ? 0 : 1) } }
    public var isComplete: Bool { !cells.contains(0) }

    /// True when no house contains a repeated value.
    public var isConsistent: Bool {
        for h in Geometry.houses {
            var seen: DigitMask = 0
            for c in h where cells[c] != 0 {
                let b = Mask.bit(Int(cells[c]))
                if seen & b != 0 { return false }
                seen |= b
            }
        }
        return true
    }

    /// Multi-line, human-readable board.
    public var pretty: String {
        var s = ""
        for r in 0..<9 {
            if r % 3 == 0 && r > 0 { s += "------+-------+------\n" }
            for c in 0..<9 {
                if c % 3 == 0 && c > 0 { s += "| " }
                let v = cells[r * 9 + c]
                s += (v == 0 ? "." : String(v)) + " "
            }
            s += "\n"
        }
        return s
    }
}
