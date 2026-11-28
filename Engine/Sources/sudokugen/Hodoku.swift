import Foundation
import SudokuCore

/// Cross-checking our technique detectors against HoDoKu, run as a separate program (its
/// "Find All Steps" batch mode). Only HoDoKu's output is read; none of its code is used.
///
/// The soundness tests catch a detector that removes a wrong candidate; this catches one that
/// misses real instances. Both programs look at the same positions (the stuck positions of
/// `Census`, notes included), and per technique we compare everything each one removes.
enum Hodoku {
    /// HoDoKu's library format: `:0000:x:<grid>:<deleted candidates>::`, where placed (non-given)
    /// digits carry a `+` and deleted candidates are `<digit><row><col>`, space-separated.
    static func libraryLine(_ b: Board) -> String {
        var grid = ""
        for c in 0..<81 {
            if b.isEmpty(c) { grid += "." } else { grid += (b.givens.contains(c) ? "" : "+") + String(b.value(c)) }
        }
        let full = Board(b.grid)   // every candidate the placed digits allow
        var deleted: [String] = []
        for c in 0..<81 where b.isEmpty(c) {
            for d in Mask.digits(full.candidates[c] & ~b.candidates[c]) {
                deleted.append("\(d)\(Geometry.rowOf[c] + 1)\(Geometry.colOf[c] + 1)")
            }
        }
        return ":0000:x:\(grid):\(deleted.joined(separator: " "))::"
    }

    /// Reads a line written by `libraryLine` back into a board.
    static func board(fromLibraryLine line: Substring) -> Board? {
        let parts = line.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count >= 5 else { return nil }
        var values: [UInt8] = []
        var givens: [Int] = []
        var placed = false
        for ch in parts[3] {
            if ch == "+" { placed = true; continue }
            let v = ch.wholeNumberValue.map(UInt8.init) ?? 0
            if v != 0 && !placed { givens.append(values.count) }
            values.append(v)
            placed = false
        }
        guard values.count == 81 else { return nil }
        var candidates = Board(Grid(cells: values)).candidates
        for code in parts[4].split(separator: " ") {
            let n = code.compactMap(\.wholeNumberValue)
            guard n.count == 3 else { return nil }
            candidates[(n[1] - 1) * 9 + n[2] - 1] &= ~Mask.bit(n[0])
        }
        return Board(values: values, candidates: candidates, givens: CellSet(givens))
    }

    /// One step HoDoKu reported: its technique name, the whole line, and what it removes/places.
    struct Found {
        var name: String
        var line: String
        var eliminated: Set<Candidate>
        var placed: Set<Candidate>
    }

    /// Parses `/bsaf` output into the steps found for each position, in input order. A position's
    /// block starts with a line ending in ` #<n>`; its steps follow, indented.
    static func parse(_ text: String) -> [Int: [Found]] {
        var out: [Int: [Found]] = [:]
        var current: Int?
        for raw in text.split(separator: "\n") {
            let line = String(raw)
            if !line.hasPrefix(" "), let hash = line.range(of: " #", options: .backwards), let n = Int(line[hash.upperBound...]) {
                current = n
                out[n, default: []] = out[n] ?? []
                continue
            }
            guard let n = current, line.hasPrefix("   "), let colon = line.firstIndex(of: ":") else { continue }
            let name = line[..<colon].trimmingCharacters(in: .whitespaces)
            let body = line[line.index(after: colon)...]
            // Effects follow "=>" when there is one, else the body is the placement ("r8c8=1").
            let effects = body.range(of: "=>").map { String(body[$0.upperBound...]) } ?? String(body)
            let (eliminated, placed) = parseEffects(effects)
            out[n, default: []].append(Found(name: name, line: line.trimmingCharacters(in: .whitespaces), eliminated: eliminated, placed: placed))
        }
        return out
    }

    /// "r7c9,r8c8,r9c1245<>5, r8c8<>9" or "r8c8=1": groups split by ", ", cells within a group by
    /// ",", and rXcY with several digits on either side meaning every combination.
    static func parseEffects(_ s: String) -> (eliminated: Set<Candidate>, placed: Set<Candidate>) {
        var eliminated = Set<Candidate>(), placed = Set<Candidate>()
        for group in s.components(separatedBy: ", ") {
            let g = group.trimmingCharacters(in: .whitespaces)
            let elim = g.range(of: "<>")
            guard let op = elim ?? g.range(of: "=") else { continue }
            let digits = g[op.upperBound...].compactMap(\.wholeNumberValue)
            for cellSpec in g[..<op.lowerBound].split(separator: ",") {
                guard cellSpec.first == "r", let cIndex = cellSpec.firstIndex(of: "c") else { continue }
                let rows = cellSpec[cellSpec.index(after: cellSpec.startIndex)..<cIndex].compactMap(\.wholeNumberValue)
                let cols = cellSpec[cellSpec.index(after: cIndex)...].compactMap(\.wholeNumberValue)
                for r in rows { for c in cols { for d in digits where (1...9).contains(d) {
                    let cand = Candidate((r - 1) * 9 + c - 1, d)
                    if elim != nil { eliminated.insert(cand) } else { placed.insert(cand) }
                } } }
            }
        }
        return (eliminated, placed)
    }

    /// Our technique for a HoDoKu step name; nil for steps we have no counterpart for (dual
    /// patterns, templates, big fish, forcing chains) or that aren't probed (singles).
    static func technique(_ name: String) -> Technique? {
        switch name {
        case "Locked Candidates Type 1 (Pointing)": return .pointing
        case "Locked Candidates Type 2 (Claiming)": return .claiming
        case "Locked Pair": return .lockedPair
        case "Locked Triple": return .lockedTriple
        case "Naked Pair": return .nakedPair
        case "Naked Triple": return .nakedTriple
        case "Naked Quadruple": return .nakedQuad
        case "Hidden Pair": return .hiddenPair
        case "Hidden Triple": return .hiddenTriple
        case "Hidden Quadruple": return .hiddenQuad
        case "X-Wing": return .xWing
        case "Swordfish": return .swordfish
        case "Jellyfish": return .jellyfish
        case "Finned X-Wing": return .finnedXWing
        case "Sashimi X-Wing": return .sashimiXWing
        case "Finned Swordfish": return .finnedSwordfish
        case "Sashimi Swordfish": return .sashimiSwordfish
        case "Finned Jellyfish": return .finnedJellyfish
        case "Sashimi Jellyfish": return .sashimiJellyfish
        case "Skyscraper": return .skyscraper
        case "2-String Kite": return .twoStringKite
        case "Turbot Fish": return .turbotFish
        case "Empty Rectangle": return .emptyRectangle
        case "XY-Wing": return .xyWing
        case "XYZ-Wing": return .xyzWing
        case "W-Wing": return .wWing
        case "WXYZ-Wing": return .wxyzWing
        case "Uniqueness Test 1": return .uniqueRectangle1
        case "Uniqueness Test 2": return .uniqueRectangle2
        case "Uniqueness Test 3": return .uniqueRectangle3
        case "Uniqueness Test 4": return .uniqueRectangle4
        case "Uniqueness Test 5": return .uniqueRectangle5
        case "Uniqueness Test 6": return .uniqueRectangle6
        case "Hidden Rectangle": return .hiddenRectangle
        case "Avoidable Rectangle Type 1": return .avoidableRectangle
        case "Avoidable Rectangle Type 2": return .avoidableRectangle2
        case "Bivalue Universal Grave + 1": return .bugPlusOne
        case "Simple Colors Trap": return .simpleColoring
        case "Simple Colors Wrap": return .colorWrap
        case "Multi Colors 1", "Multi Colors 2": return .multiColoring
        case "Remote Pair": return .remotePair
        case "X-Chain": return .xChain
        case "XY-Chain": return .xyChain
        case "Continuous Nice Loop": return .niceLoop
        case "Discontinuous Nice Loop": return .discontinuousNiceLoop
        case "AIC": return .aic
        case "Grouped Continuous Nice Loop", "Grouped Discontinuous Nice Loop", "Grouped AIC": return .groupedAIC
        case "Franken X-Wing", "Franken Swordfish", "Franken Jellyfish",
             "Finned Franken X-Wing", "Finned Franken Swordfish", "Finned Franken Jellyfish": return .frankenFish
        case "Mutant X-Wing", "Mutant Swordfish", "Mutant Jellyfish",
             "Finned Mutant X-Wing", "Finned Mutant Swordfish", "Finned Mutant Jellyfish": return .mutantFish
        case "Kraken Fish", "Kraken Fish Type 1", "Kraken Fish Type 2": return .krakenFish
        case "Sue de Coq": return .sueDeCoq
        case "Almost Locked Set XZ-Rule": return .alsXZ
        case "Almost Locked Set XY-Wing": return .alsXYWing
        case "Almost Locked Set Chain": return .alsChain
        case "Death Blossom": return .deathBlossom
        default: return nil
        }
    }

    /// Families of techniques whose names HoDoKu splits differently (which shape is a Skyscraper
    /// and which a Turbot Fish, a Locked Pair or a Naked Pair, an AIC or a Nice Loop). A HoDoKu
    /// finding counts as truly missed only when none of our techniques in its family finds it.
    static let families: [[Technique]] = [
        [.pointing, .claiming, .lockedPair, .lockedTriple, .nakedPair, .nakedTriple, .nakedQuad, .hiddenPair, .hiddenTriple, .hiddenQuad],
        [.xWing, .swordfish, .jellyfish, .finnedXWing, .sashimiXWing, .finnedSwordfish, .sashimiSwordfish, .finnedJellyfish, .sashimiJellyfish],
        [.skyscraper, .twoStringKite, .turbotFish, .emptyRectangle, .xChain, .simpleColoring, .colorWrap, .multiColoring],
        [.xyWing, .xyzWing, .wWing, .wxyzWing, .remotePair, .xyChain],
        [.uniqueRectangle1, .uniqueRectangle2, .uniqueRectangle3, .uniqueRectangle4, .uniqueRectangle5, .uniqueRectangle6,
         .hiddenRectangle, .avoidableRectangle, .avoidableRectangle2, .bugPlusOne, .uniqueRectangleMissing],
        [.remotePair, .xChain, .xyChain, .niceLoop, .discontinuousNiceLoop, .aic, .groupedAIC],
        [.frankenFish, .mutantFish, .krakenFish],
        // HoDoKu reports a one-link Simple Colors Trap, which is just locked candidates.
        [.pointing, .claiming, .simpleColoring, .multiColoring],
        [.sueDeCoq, .alsXZ, .alsXYWing, .alsChain, .deathBlossom],
    ]

    static func family(of t: Technique) -> Set<Technique> {
        Set(families.filter { $0.contains(t) }.joined()).union([t])
    }

    struct Tally {
        var both = 0, hodokuOnly = 0, oursOnly = 0, hodokuFindsMore = 0, missed = 0, oursFindsMore = 0
        var examples: [String] = [], oursExamples: [String] = []
    }

    /// What a step removes from `b`: its eliminations, and for each placement every other
    /// candidate of the cell plus the digit in the cell's peers. HoDoKu writes some placements as
    /// eliminations ("r8c6<>4, r8c6<>5, r8c6<>6") and we write them as placements, or back.
    static func removals(eliminated: Set<Candidate>, placed: Set<Candidate>, _ b: Board) -> Set<Candidate> {
        var out = eliminated
        for e in placed where b.isEmpty(e.cell) {
            for d in Mask.digits(b.candidates[e.cell]) where d != e.digit { out.insert(Candidate(e.cell, d)) }
            for p in Geometry.peers[e.cell] where b.has(p, e.digit) { out.insert(Candidate(p, e.digit)) }
        }
        return out.filter { b.has($0.cell, $0.digit) }
    }

    /// Everything one of our techniques removes in a position, over all its instances.
    static func ourRemovals(_ b: Board, _ t: Technique, probe: HumanSolver) -> Set<Candidate> {
        probe.allSteps(b, technique: t).reduce(into: Set<Candidate>()) {
            $0.formUnion(removals(eliminated: Set($1.eliminations), placed: Set($1.placements), b))
        }
    }

    static func describe(_ cs: Set<Candidate>) -> String {
        cs.sorted { ($0.cell, $0.digit) < ($1.cell, $1.digit) }.map(\.description).joined(separator: " ")
    }

    /// Compares, per technique and position, everything our detector removes or places with
    /// everything HoDoKu's does.
    static func compare(positions: [Substring], hodoku: [Int: [Found]], examples: Int) -> (tallies: [Technique: Tally], unmapped: [String: Int], positions: Int) {
        let probe = HumanSolver(allowing: Set(Census.probed))
        let results = Locked([Technique: Tally]())
        let unmapped = Locked([String: Int]())
        let compared = Locked(0)
        DispatchQueue.concurrentPerform(iterations: positions.count) { i in
            guard let board = board(fromLibraryLine: positions[i]), let found = hodoku[i + 1] else { return }
            compared.with { $0 += 1 }
            var theirs: [Technique: [Found]] = [:]
            for f in found {
                if let t = technique(f.name) { theirs[t, default: []].append(f) } else { unmapped.with { $0[f.name, default: 0] += 1 } }
            }
            var ours: [Technique: Set<Candidate>] = [:]
            for t in Census.probed { ours[t] = ourRemovals(board, t, probe: probe) }
            for t in Census.probed {
                let mine = ours[t] ?? []
                let hd = (theirs[t] ?? []).reduce(into: Set<Candidate>()) { $0.formUnion(removals(eliminated: $1.eliminated, placed: $1.placed, board)) }
                guard !mine.isEmpty || !hd.isEmpty else { continue }
                let familyFinds = family(of: t).reduce(into: Set<Candidate>()) { $0.formUnion(ours[$1] ?? []) }
                let missed = hd.subtracting(familyFinds)
                results.with { all in
                    var tally = all[t] ?? Tally()
                    if mine.isEmpty { tally.hodokuOnly += 1 } else if hd.isEmpty { tally.oursOnly += 1 } else { tally.both += 1 }
                    if !hd.isSubset(of: mine) { tally.hodokuFindsMore += 1 }
                    if !missed.isEmpty { tally.missed += 1 }
                    if !mine.isSubset(of: hd) { tally.oursFindsMore += 1 }
                    if !missed.isEmpty && tally.examples.count < examples {
                        let culprits = (theirs[t] ?? []).filter { !removals(eliminated: $0.eliminated, placed: $0.placed, board).isDisjoint(with: missed) }.prefix(3).map(\.line)
                        tally.examples.append("position \(i + 1): no \(t.rawValue)-family technique of ours finds \(describe(missed))\n      \(positions[i])\n      " + culprits.joined(separator: "\n      "))
                    }
                    if !mine.isSubset(of: hd) && tally.oursExamples.count < examples {
                        let steps = probe.allSteps(board, technique: t).filter { !removals(eliminated: Set($0.eliminations), placed: Set($0.placements), board).isSubset(of: hd) }
                        tally.oursExamples.append("position \(i + 1): HoDoKu's \(t.rawValue) doesn't find \(describe(mine.subtracting(hd)))\n      \(positions[i])\n      " + steps.prefix(2).map(\.explanation).joined(separator: "\n      "))
                    }
                    all[t] = tally
                }
            }
        }
        return (results.with { $0 }, unmapped.with { $0 }, compared.with { $0 })
    }
}
