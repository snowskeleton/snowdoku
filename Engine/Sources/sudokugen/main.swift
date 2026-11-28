import Dispatch
import Foundation
import SudokuCore

let usage = """
sudokugen — Snowdoku puzzle tooling

  sudokugen solve <puzzle>                 Step-by-step human-style solve
  sudokugen rate <puzzle|-> ...            Rate puzzles (from args or stdin, one per line)
  sudokugen generate [options]             Generate and rate puzzles (TSV to stdout)
      --count N         number of puzzles to output (default 10)
      --difficulty D    beginner|easy|medium|hard|expert|master|extreme
      --technique T     require a technique (raw name, e.g. xWing)
      --symmetry S      none|rotational180|rotational90|mirror|diagonal
      --seed N          base seed (default: random)
      --threads N       worker threads (default: all cores)
  sudokugen stats [--count N] [--seed N]   Distribution of difficulties/techniques
  sudokugen techniques                     List techniques with scores
  sudokugen census [--min D] FILE...       For each technique, how often it applies along the solver's
                                           path (avail), adds something no easier technique does
                                           (novel), and is the solver's pick (chosen). Puzzles are the
                                           first column of each line; --min keeps tier D and harder
  sudokugen bank-tiers FILE                Each bundled-bank line's puzzle and tier, tab-separated
  sudokugen hodoku-positions [--min D] [--limit N] FILE...
                                           The census's stuck positions (notes included) in HoDoKu's
                                           library format, for `java -jar hodoku.jar /bsaf`
  sudokugen hodoku-compare [--examples N] POSITIONS HODOKU_OUTPUT
                                           Per technique, positions where HoDoKu's Find All Steps
                                           removes candidates our detector doesn't, and vice versa
  sudokugen mutate --from FILE [--count N] [--minutes M]
                                           Find more extreme puzzles (ones that need forcing chains)
                                           by swapping clues in known ones (puzzles to stdout)
  sudokugen drills [options]               Mine "next move is X" training positions (JSON to stdout)
      --per N           drills per technique (default 20)
      --technique T     only these techniques (comma-separated)
      --minutes M       stop after M minutes even if some techniques are short (default 10)
      --from FILE       mine these puzzles (one per line) instead of random ones, each once
      --seed N, --threads N
  sudokugen campaign [options]             Mine campaign puzzles: every one found, best first per target
                                           (JSON lines to stdout, summary to stderr)
      --chapter IDs     chapters (comma-separated ids, default all)
      --kind K          spotlight,context,mixed,boss,endless (comma-separated, default all)
      --minutes M       time budget for the whole run (default 5)
      --enough N        stop favoring a target once it has N puzzles (endless: 3N; default 60)
      --bank FILE       seed from these puzzles (first column), e.g. App/Resources/Puzzles.tsv;
                        bank puzzles that qualify go straight into the endless pools
      --iterations N    hill-climb steps per seed (default 150)
      --seeds FILES     start from the best puzzles already mined for each target (comma-separated
                        JSON-lines files from earlier runs; missing ones are skipped), so climbs
                        continue from the best so far
      --elites N        how many of a target's best puzzles to climb from (default 10)
      --coverage       instead, count the --bank puzzles that already qualify for each endless pool
      --seed N, --threads N
  sudokugen campaign-chapters              The campaign's chapters as JSON (for Design/achievements)
  sudokugen campaign-merge [--per N] [--endless N] FILE...
                                           Pick the bundled campaign from mined files: the best N per
                                           chapter, kind and spotlight member (default 8; endless 150)
  sudokugen bank [--per N] FILE...        Rate puzzles (first column of each line) into the bundled
                                           bank format, easiest tier first; drops duplicates, invalid
                                           puzzles and ones that need trial and error
  sudokugen bank-stats [FILE]              How many bank puzzles use each technique, in all and per tier,
                                           and how many have it as their hardest (default FILE:
                                           App/Resources/Puzzles.tsv); lists techniques no puzzle uses
  sudokugen merge-drills [--per N] FILE...  Combine drill files, drop broken or duplicate drills, and
                                           put the clearest example first for each technique
"""

func fail(_ s: String) -> Never {
    FileHandle.standardError.write((s + "\n").data(using: .utf8)!)
    exit(1)
}

func option(_ name: String, in args: [String]) -> String? {
    guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
    return args[i + 1]
}

func tsv(_ p: GeneratedPuzzle) -> String {
    let techs = p.rating.techniques.map(\.rawValue).joined(separator: ",")
    return "\(p.puzzle.string)\t\(p.rating.difficulty.name)\t\(p.rating.hardest.rawValue)\t\(p.rating.totalScore)\t\(techs)"
}

final class Locked<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var value: T
    init(_ v: T) { value = v }
    func with<R>(_ f: (inout T) -> R) -> R { lock.lock(); defer { lock.unlock() }; return f(&value) }
}

let args = Array(CommandLine.arguments.dropFirst())
guard let cmd = args.first else { print(usage); exit(0) }

switch cmd {
case "techniques":
    for t in Technique.allCases.sorted(by: { $0.score < $1.score }) {
        print("\(String(t.score).padding(toLength: 5, withPad: " ", startingAt: 0))\(t.difficulty.name.padding(toLength: 10, withPad: " ", startingAt: 0))\(t.name)  [\(t.rawValue)]")
    }

case "solve":
    guard args.count > 1, let g = Grid(args[1]) else { fail("Usage: sudokugen solve <81-char puzzle>") }
    guard case .unique(let sol) = BruteForce.analyze(g) else { fail("Puzzle does not have a unique solution.") }
    print(g.pretty)
    let start = Date()
    let log = HumanSolver().solve(Board(g), solution: sol)
    for (i, s) in log.steps.enumerated() {
        print("\(i + 1). [\(s.technique.name)] \(s.explanation)")
    }
    let r = Rater.rating(from: log.steps)
    print("\nRating: \(r.difficulty.name), hardest \(r.hardest.name), total \(r.totalScore), \(r.stepCount) steps, \(String(format: "%.0f", Date().timeIntervalSince(start) * 1000)) ms")

case "rate":
    var lines = Array(args.dropFirst())
    if lines.isEmpty || lines == ["-"] {
        lines = []
        while let l = readLine() { lines.append(l) }
    }
    // Rated in parallel, printed in input order.
    let raws = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.map { String($0.split(separator: "\t").first ?? "") }
    let outputs = Locked([String](repeating: "", count: raws.count))
    DispatchQueue.concurrentPerform(iterations: raws.count) { i in
        let raw = raws[i]
        let line: String
        if let g = Grid(raw), let r = Rater.rate(g) {
            line = "\(g.string)\t\(r.difficulty.name)\t\(r.hardest.rawValue)\t\(r.totalScore)\t\(r.techniques.map(\.rawValue).joined(separator: ","))"
        } else {
            line = "\(raw)\tINVALID"
        }
        outputs.with { $0[i] = line }
    }
    for line in outputs.with({ $0 }) { print(line) }

case "generate", "stats":
    let count = Int(option("--count", in: args) ?? "") ?? (cmd == "stats" ? 200 : 10)
    let difficulty = option("--difficulty", in: args).flatMap { name in Difficulty.allCases.first { $0.name.lowercased() == name.lowercased() } }
    let technique = option("--technique", in: args).flatMap(Technique.init(rawValue:))
    let symmetry = option("--symmetry", in: args).flatMap(Symmetry.init(rawValue:)) ?? .none
    let seed = UInt64(option("--seed", in: args) ?? "") ?? UInt64.random(in: 0...UInt64.max)
    let threads = Int(option("--threads", in: args) ?? "") ?? ProcessInfo.processInfo.activeProcessorCount
    if option("--difficulty", in: args) != nil && difficulty == nil { fail("Unknown difficulty") }
    if option("--technique", in: args) != nil && technique == nil { fail("Unknown technique") }

    let results = Locked<[GeneratedPuzzle]>([])
    let attempts = Locked(0)
    let start = Date()
    DispatchQueue.concurrentPerform(iterations: threads) { worker in
        var mixer = SplitMix64(seed: seed ^ (UInt64(worker) &* 0xD1B5_4A32_D192_ED03))
        var rng = SplitMix64(seed: mixer.next())
        let solver = HumanSolver()
        while results.with({ $0.count }) < count {
            let (p, s) = Generator.makePuzzle(symmetry: symmetry, using: &rng)
            attempts.with { $0 += 1 }
            let rated = difficulty.map { Rater.rate(p, solution: s, ifIn: $0) } ?? Rater.rate(p, solution: s, solver: solver)
            guard let r = rated else { continue }
            if let technique, r.counts[technique] == nil { continue }
            let gp = GeneratedPuzzle(puzzle: p, solution: s, rating: r)
            let emitted = results.with { list -> Bool in
                guard list.count < count, !list.contains(where: { $0.puzzle == gp.puzzle }) else { return false }
                list.append(gp)
                return true
            }
            if emitted && cmd == "generate" {
                let line = tsv(gp)
                results.with { _ in print(line); fflush(nil) }
            }
        }
    }
    let elapsed = Date().timeIntervalSince(start)
    let list = results.with { $0 }
    let n = attempts.with { $0 }
    FileHandle.standardError.write("\(list.count) puzzles from \(n) attempts in \(String(format: "%.1f", elapsed))s (\(String(format: "%.1f", Double(n) / elapsed)) puzzles/s)\n".data(using: .utf8)!)
    if cmd == "stats" {
        var byDiff: [Difficulty: Int] = [:]
        var byHardest: [Technique: Int] = [:]
        var used: [Technique: Int] = [:]
        for p in list {
            byDiff[p.rating.difficulty, default: 0] += 1
            byHardest[p.rating.hardest, default: 0] += 1
            for t in p.rating.techniques { used[t, default: 0] += 1 }
        }
        print("Difficulty distribution:")
        for d in Difficulty.allCases { print("  \(d.name.padding(toLength: 10, withPad: " ", startingAt: 0)) \(byDiff[d] ?? 0)") }
        print("Hardest technique:")
        for (t, c) in byHardest.sorted(by: { $0.key.score < $1.key.score }) { print("  \(t.name.padding(toLength: 28, withPad: " ", startingAt: 0)) \(c)") }
        print("Puzzles using technique:")
        for (t, c) in used.sorted(by: { $0.key.score < $1.key.score }) { print("  \(t.name.padding(toLength: 28, withPad: " ", startingAt: 0)) \(c)") }
    }

case "census":
    let minName = option("--min", in: args)
    let minTier = minName.flatMap { n in Difficulty.allCases.first { $0.name.lowercased() == n.lowercased() } }
    if minName != nil && minTier == nil { fail("Unknown difficulty") }
    var files: [String] = []
    var rest = args.dropFirst().makeIterator()
    while let a = rest.next() {
        if a == "--min" { _ = rest.next() } else { files.append(a) }
    }
    if files.isEmpty { fail("Usage: sudokugen census [--min D] FILE...") }
    var lines: [Substring] = []
    for f in files {
        guard let text = try? String(contentsOfFile: f, encoding: .utf8) else { fail("Can't read \(f)") }
        lines += text.split(separator: "\n")
    }
    let inputs = lines
    let start = Date()
    let total = Locked(Census())
    DispatchQueue.concurrentPerform(iterations: inputs.count) { i in
        guard let g = Grid(String(inputs[i].split(separator: "\t").first ?? "")) else { return }
        if let minTier {
            // Bank lines carry their tier; anything else gets rated.
            let tier = BankedPuzzle(line: inputs[i])?.difficulty ?? Rater.rate(g)?.difficulty
            guard let tier, tier >= minTier else { return }
        }
        let c = Census.of(g)
        total.with { $0.add(c) }
    }
    let census = total.with { $0 }
    print("\(census.puzzles) puzzles\(minTier.map { " (\($0.name)+)" } ?? ""), \(census.stuckPositions) stuck positions on the solver's path, \(Int(Date().timeIntervalSince(start)))s")
    print("technique".padding(toLength: 26, withPad: " ", startingAt: 0) + "score  avail  novel chosen puzzles")
    for t in Census.probed {
        let c = census.counts[t] ?? Census.Counts()
        print(t.rawValue.padding(toLength: 26, withPad: " ", startingAt: 0) + String(format: "%5d %6d %6d %6d %7d", t.score, c.available, c.novel, c.chosen, c.puzzles))
    }

case "bank-tiers":
    guard args.count > 1, let text = try? String(contentsOfFile: args[1], encoding: .utf8) else { fail("Usage: sudokugen bank-tiers FILE") }
    for l in text.split(separator: "\n") {
        if let p = BankedPuzzle(line: l) { print("\(p.puzzle.string)\t\(p.difficulty.name)") }
    }

case "hodoku-positions":
    let minName = option("--min", in: args)
    let minTier = minName.flatMap { n in Difficulty.allCases.first { $0.name.lowercased() == n.lowercased() } }
    if minName != nil && minTier == nil { fail("Unknown difficulty") }
    let limit = Int(option("--limit", in: args) ?? "") ?? Int.max
    var files: [String] = []
    var rest = args.dropFirst().makeIterator()
    while let a = rest.next() {
        if a == "--min" || a == "--limit" { _ = rest.next() } else { files.append(a) }
    }
    var grids: [Grid] = []
    for f in files {
        guard let text = try? String(contentsOfFile: f, encoding: .utf8) else { fail("Can't read \(f)") }
        for l in text.split(separator: "\n") {
            guard let g = Grid(String(l.split(separator: "\t").first ?? "")) else { continue }
            if let minTier {
                let tier = BankedPuzzle(line: l)?.difficulty ?? Rater.rate(g)?.difficulty
                guard let tier, tier >= minTier else { continue }
            }
            grids.append(g)
        }
    }
    let chosen = Array(grids.prefix(limit))
    let lines = Locked([[String]](repeating: [], count: chosen.count))
    DispatchQueue.concurrentPerform(iterations: chosen.count) { i in
        let out = Census.stuckPositions(of: chosen[i]).map { Hodoku.libraryLine($0.board) }
        lines.with { $0[i] = out }
    }
    for l in lines.with({ $0 }).joined() { print(l) }

case "hodoku-compare":
    let examples = Int(option("--examples", in: args) ?? "") ?? 0
    var files: [String] = []
    var rest = args.dropFirst().makeIterator()
    while let a = rest.next() {
        if a == "--examples" { _ = rest.next() } else { files.append(a) }
    }
    guard files.count == 2, let posText = try? String(contentsOfFile: files[0], encoding: .utf8),
          let hdText = try? String(contentsOfFile: files[1], encoding: .utf8) else {
        fail("Usage: sudokugen hodoku-compare [--examples N] POSITIONS HODOKU_OUTPUT")
    }
    let positions = posText.split(separator: "\n")
    let (tallies, unmapped, compared) = Hodoku.compare(positions: positions, hodoku: Hodoku.parse(hdText), examples: examples)
    print("\(compared) of \(positions.count) positions compared. Per technique, positions where it finds something:")
    print("  both: we and HoDoKu; hodoku/ours: only one of us; +hodoku/+ours: one removes candidates the other's same-named")
    print("  technique doesn't; MISSED: HoDoKu removes a candidate no technique of ours in the same family does")
    print("technique".padding(toLength: 26, withPad: " ", startingAt: 0) + "  both hodoku   ours +hodoku  +ours MISSED")
    for t in Census.probed {
        guard let c = tallies[t] else { continue }
        print(t.rawValue.padding(toLength: 26, withPad: " ", startingAt: 0) + String(format: "%6d %6d %6d %7d %6d %6d", c.both, c.hodokuOnly, c.oursOnly, c.hodokuFindsMore, c.oursFindsMore, c.missed))
    }
    let noCounterpart = Census.probed.filter { t in !tallies.keys.contains(t) }
    if !noCounterpart.isEmpty { print("Never found by either: \(noCounterpart.map(\.rawValue).joined(separator: ", "))") }
    print("HoDoKu steps with no counterpart here: " + unmapped.sorted { $0.value > $1.value }.map { "\($0.key) \($0.value)" }.joined(separator: ", "))
    if examples > 0 {
        for t in Census.probed {
            guard let ex = tallies[t]?.examples, !ex.isEmpty else { continue }
            print("\n\(t.rawValue): missed")
            for e in ex { print("  " + e) }
        }
        for t in Census.probed {
            guard let ex = tallies[t]?.oursExamples, !ex.isEmpty else { continue }
            print("\n\(t.rawValue): ours finds more than HoDoKu's")
            for e in ex { print("  " + e) }
        }
    }

case "bank":
    let per = Int(option("--per", in: args) ?? "") ?? Int.max
    var files: [String] = []
    var rest = args.dropFirst().makeIterator()
    while let a = rest.next() {
        if a == "--per" { _ = rest.next() } else { files.append(a) }
    }
    var seen = Set<Grid>()
    var puzzles: [Grid] = []
    for f in files {
        guard let text = try? String(contentsOfFile: f, encoding: .utf8) else { fail("Can't read \(f)") }
        for l in text.split(separator: "\n") {
            if let g = Grid(String(l.split(separator: "\t").first ?? "")), seen.insert(g).inserted { puzzles.append(g) }
        }
    }
    let inputs = puzzles
    let rated = Locked<[Int: BankedPuzzle]>([:])
    DispatchQueue.concurrentPerform(iterations: puzzles.count) { i in
        guard let r = Rater.rate(inputs[i]), r.solvedLogically else { return }
        rated.with { $0[i] = BankedPuzzle(puzzle: inputs[i], rating: r) }
    }
    let all = rated.with { $0 }
    // Input order within a tier, so appending to the inputs keeps existing lines (and dailies) in place.
    let ordered = all.keys.sorted().map { all[$0]! }
    for d in Difficulty.allCases {
        let tier = ordered.filter { $0.difficulty == d }.prefix(per)
        for p in tier { print(p.line) }
        FileHandle.standardError.write("\(d.name): \(tier.count)\n".data(using: .utf8)!)
    }

case "bank-stats":
    let path = args.dropFirst().first ?? "App/Resources/Puzzles.tsv"
    guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { fail("Can't read \(path)") }
    let lines = text.split(separator: "\n")
    let bank = lines.compactMap(BankedPuzzle.init(line:))
    if bank.count < lines.count { fail("\(lines.count - bank.count) lines in \(path) don't parse") }
    let tiers = Difficulty.allCases
    var used: [Technique: [Difficulty: Int]] = [:]
    var hardest: [Technique: Int] = [:]
    for b in bank {
        for t in b.rating.counts.keys { used[t, default: [:]][b.difficulty, default: 0] += 1 }
        hardest[b.rating.hardest, default: 0] += 1
    }
    let perTier = Dictionary(grouping: bank, by: \.difficulty).mapValues(\.count)
    print("\(bank.count) puzzles: " + tiers.map { "\($0.name) \(perTier[$0] ?? 0)" }.joined(separator: ", "))
    print("Puzzles using each technique (\"hardest\": it's the puzzle's hardest technique)\n")
    func col(_ s: String, _ w: Int) -> String { String(repeating: " ", count: max(0, w - s.count)) + s }
    print("technique".padding(toLength: 26, withPad: " ", startingAt: 0) + col("all", 6) + col("hardest", 9)
          + tiers.map { col(String($0.name.prefix(6)), 8) }.joined())
    let techniques = Technique.allCases.filter { $0 != .bruteForce }.sorted { $0.score < $1.score }
    for t in techniques {
        guard let u = used[t] else { continue }
        print(t.rawValue.padding(toLength: 26, withPad: " ", startingAt: 0) + col(String(u.values.reduce(0, +)), 6)
              + col(String(hardest[t] ?? 0), 9) + tiers.map { col(u[$0].map(String.init) ?? "·", 8) }.joined())
    }
    let unused = techniques.filter { used[$0] == nil }
    print("\nNo puzzle uses: " + (unused.isEmpty ? "none" : unused.map(\.rawValue).joined(separator: ", ")))

case "merge-drills":
    let per = Int(option("--per", in: args) ?? "") ?? 20
    var files: [String] = []
    var rest = args.dropFirst().makeIterator()
    while let a = rest.next() {
        if a == "--per" { _ = rest.next() } else { files.append(a) }
    }
    var seen = Set<Drill>()
    var byTechnique: [Technique: [Drill]] = [:]
    for f in files {
        guard let data = FileManager.default.contents(atPath: f) else { fail("Can't read \(f)") }
        for d in try JSONDecoder().decode([Drill].self, from: data) where seen.insert(d).inserted {
            byTechnique[d.technique, default: []].append(d)
        }
    }
    // Re-check every drill against the current solver order. If its next move is now a different
    // technique, it becomes a drill for that one (a singles drill only when its candidates are the
    // plain ones, since those are shown without notes).
    let all = byTechnique.values.flatMap { $0 }
    let checked = Locked<[Technique: [(drill: Drill, complexity: Int, cells: Int)]]>([:])
    let relabeled = Locked(0)
    DispatchQueue.concurrentPerform(iterations: all.count) { i in
        var d = all[i]
        guard let s = HumanSolver().nextStep(d.board) else { return }
        if s.technique != d.technique {
            if s.technique.difficulty == .beginner && Board(d.values).candidates != d.candidates { return }
            d.technique = s.technique
            relabeled.with { $0 += 1 }
        }
        checked.with { $0[d.technique, default: []].append((d, s.complexity, s.patternCells.count)) }
    }
    FileHandle.standardError.write("\(relabeled.with { $0 }) drills relabeled to a new technique\n".data(using: .utf8)!)
    // Simplest step first, then the fewest highlighted cells: that one becomes the worked example.
    let ranked = Locked<[Technique: [Drill]]>([:])
    for (t, list) in checked.with({ $0 }) {
        var unique = Set<Drill>()
        let sorted = list.sorted { ($0.complexity, $0.cells) < ($1.complexity, $1.cells) }
            .map(\.drill).filter { unique.insert($0).inserted }
        ranked.with { $0[t] = Array(sorted.prefix(per)) }
    }
    let result = ranked.with { $0 }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let list = result.keys.sorted { $0.score < $1.score }.flatMap { result[$0]! }
    let lines = try list.map { String(decoding: try encoder.encode($0), as: UTF8.self) }
    print("[\n" + lines.joined(separator: ",\n") + "\n]")
    for t in Technique.allCases where t != .bruteForce {
        FileHandle.standardError.write("\(t.rawValue): \(result[t]?.count ?? 0)\n".data(using: .utf8)!)
    }

case "mutate":
    guard let path = option("--from", in: args), let text = try? String(contentsOfFile: path, encoding: .utf8) else {
        fail("Usage: sudokugen mutate --from FILE")
    }
    let count = Int(option("--count", in: args) ?? "") ?? 100
    let minutes = Double(option("--minutes", in: args) ?? "") ?? 5
    let threads = Int(option("--threads", in: args) ?? "") ?? ProcessInfo.processInfo.activeProcessorCount
    let seed = UInt64(option("--seed", in: args) ?? "") ?? UInt64.random(in: 0...UInt64.max)
    // Gets stuck exactly when a puzzle needs a forcing technique (or trial and error).
    let nonForcing = HumanSolver(allowing: Set(Technique.allCases.filter { $0.difficulty < .extreme }))
    let candidates = text.split(separator: "\n").compactMap { Grid(String($0.split(separator: "\t").first ?? "")) }
    let keep = Locked([Bool](repeating: false, count: candidates.count))
    DispatchQueue.concurrentPerform(iterations: candidates.count) { i in
        let g = candidates[i]
        let ok = BruteForce.hasUniqueSolution(g) && !nonForcing.solve(Board(g)).solved
        keep.with { $0[i] = ok }
    }
    let kept = keep.with { $0 }
    let seeds = candidates.indices.filter { kept[$0] }.map { candidates[$0] }
    guard !seeds.isEmpty else { fail("No extreme puzzles in \(path)") }
    let pool = Locked(seeds)
    let tries = Locked(0)
    let deadline = Date().addingTimeInterval(minutes * 60)
    DispatchQueue.concurrentPerform(iterations: threads) { worker in
        var rng = SplitMix64(seed: seed ^ (UInt64(worker) &* 0x9E37_79B9_7F4A_7C15))
        while Date() < deadline, pool.with({ $0.count }) < seeds.count + count {
            var g = pool.with { $0.randomElement(using: &rng)! }
            tries.with { $0 += 1 }
            // Move one clue: drop a random one, then add a random digit somewhere it fits.
            let clues = (0..<81).filter { g[$0] != 0 }
            g[clues.randomElement(using: &rng)!] = 0
            let empty = (0..<81).filter { g[$0] == 0 }
            let cell = empty.randomElement(using: &rng)!
            let used = Set(Geometry.peers[cell].map { g[$0] })
            guard let digit = (1...9).filter({ !used.contains($0) }).randomElement(using: &rng) else { continue }
            g[cell] = digit
            guard BruteForce.hasUniqueSolution(g), !nonForcing.solve(Board(g)).solved else { continue }
            let added = pool.with { list -> Bool in
                guard !list.contains(g) else { return false }
                list.append(g)
                return true
            }
            if added { pool.with { _ in print(g.string); fflush(nil) } }
        }
    }
    FileHandle.standardError.write("\(pool.with { $0.count } - seeds.count) new extreme puzzles from \(tries.with { $0 }) tries\n".data(using: .utf8)!)

case "campaign":
    let minutes = Double(option("--minutes", in: args) ?? "") ?? 5
    let iterations = Int(option("--iterations", in: args) ?? "") ?? 150
    let threads = Int(option("--threads", in: args) ?? "") ?? ProcessInfo.processInfo.activeProcessorCount
    let seed = UInt64(option("--seed", in: args) ?? "") ?? UInt64.random(in: 0...UInt64.max)
    // Stop climbing for a target once it has this many puzzles (endless pools want more).
    let enough = Int(option("--enough", in: args) ?? "") ?? 60
    let chapters: [CampaignChapter] = option("--chapter", in: args).map { list in
        list.split(separator: ",").map { id in
            guard let c = CampaignChapter.named(String(id)) else { fail("Unknown chapter \(id)") }
            return c
        }
    } ?? CampaignChapter.all
    let kinds: [CampaignKind] = option("--kind", in: args).map { list in
        list.split(separator: ",").map { k in
            guard let kind = CampaignKind(rawValue: String(k)) else { fail("Unknown kind \(k)") }
            return kind
        }
    } ?? CampaignKind.allCases
    let targets = chapters.flatMap { CampaignTarget.all(for: $0, kinds: kinds) }
    let target: @Sendable (CampaignTarget) -> Int = { t in t.kind == .endless ? enough * 3 : enough }
    // Bank puzzles that use a chapter's family are good seeds for it.
    let bankSeeds: [String: [Grid]] = option("--bank", in: args).map { path in
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { fail("Can't read \(path)") }
        let bank = BankedPuzzle.parse(text)
        return Dictionary(uniqueKeysWithValues: chapters.map { ch in
            (ch.id, bank.filter { !ch.familySet.isDisjoint(with: $0.rating.counts.keys) }.map(\.puzzle))
        })
    } ?? [:]
    if args.contains("--coverage") {
        // How many bank puzzles already qualify for each chapter's endless pool.
        for ch in chapters {
            let t = CampaignTarget(chapter: ch, kind: .endless, member: nil)
            let pool = bankSeeds[ch.id] ?? []
            let ok = Locked(0)
            DispatchQueue.concurrentPerform(iterations: pool.count) { i in
                if CampaignMiner.evaluate(pool[i], t).mined != nil { ok.with { $0 += 1 } }
            }
            print("\(ch.id)\t\(ok.with { $0 })\tof \(pool.count) bank puzzles using the family")
        }
        exit(0)
    }
    let found = Locked<[CampaignTarget: [String: Mined]]>([:])
    // One puzzle per solution grid (the best), so a pool isn't near-duplicates of one puzzle.
    @Sendable func record(_ m: Mined, _ t: CampaignTarget) {
        guard let solution = BruteForce.solution(m.puzzle) else { return }
        found.with { f in
            if f[t]?[solution.string].map({ m.score > $0.score }) ?? true { f[t, default: [:]][solution.string] = m }
        }
    }
    // Bank puzzles that already qualify go straight into the endless pools.
    for t in targets where t.kind == .endless {
        let pool = bankSeeds[t.chapter.id] ?? []
        DispatchQueue.concurrentPerform(iterations: pool.count) { i in
            if let m = CampaignMiner.evaluate(pool[i], t).mined { record(m, t) }
        }
    }
    // Earlier runs' best puzzles per target (one per solution grid, re-scored by this engine):
    // climbs start from them as well as from this run's best.
    let eliteCount = Int(option("--elites", in: args) ?? "") ?? 10
    let seedElites: [CampaignTarget: [Mined]] = option("--seeds", in: args).map { list in
        var byTarget: [CampaignTarget: [CampaignPuzzle]] = [:]
        let decoder = JSONDecoder()
        for path in list.split(separator: ",").map(String.init) {
            guard let text = try? String(contentsOfFile: path, encoding: .utf8) else {
                FileHandle.standardError.write("Skipping seeds \(path): can't read it\n".data(using: .utf8)!)
                continue
            }
            for line in text.split(separator: "\n") {
                guard let p = try? decoder.decode(CampaignPuzzle.self, from: Data(line.utf8)) else { continue }
                // Endless takes any non-spotlight puzzle of its chapter, as `campaign-merge` does.
                for t in targets where t.chapter.id == p.chapter
                    && (t.kind == p.kind || (t.kind == .endless && p.kind != .spotlight)) && t.member == p.member {
                    byTarget[t, default: []].append(p)
                }
            }
        }
        // Re-score only the most promising few per target, by their stored score.
        let jobs = byTarget.flatMap { t, ps in
            ps.sorted { $0.score > $1.score }.prefix(eliteCount * 4).map { (t, $0.puzzle) }
        }
        let scored = Locked<[CampaignTarget: [String: Mined]]>([:])
        DispatchQueue.concurrentPerform(iterations: jobs.count) { i in
            let (t, g) = jobs[i]
            guard let m = CampaignMiner.evaluate(g, t).mined, let solution = BruteForce.solution(g) else { return }
            scored.with { s in
                if s[t]?[solution.string].map({ m.score > $0.score }) ?? true { s[t, default: [:]][solution.string] = m }
            }
        }
        let result = scored.with { $0 }.mapValues { Array($0.values.sorted { $0.score > $1.score }.prefix(eliteCount)) }
        for t in targets {
            let best = result[t]?.map(\.analysis.uses) ?? []
            FileHandle.standardError.write("seeds \(t): \(best.count), uses \(best.map(String.init).joined(separator: " "))\n".data(using: .utf8)!)
        }
        fflush(nil)
        return result
    } ?? [:]
    let climbs = Locked(0)
    let climbsPer = Locked<[CampaignTarget: Int]>([:])
    let start = Date()
    let deadline = start.addingTimeInterval(minutes * 60)
    DispatchQueue.concurrentPerform(iterations: threads) { worker in
        var rng = SplitMix64(seed: seed ^ (UInt64(worker) &* 0x9E37_79B9_7F4A_7C15))
        while Date() < deadline {
            // Share the time evenly among the targets that are still short, then among all.
            let full = found.with { f in Set(targets.filter { (f[$0]?.count ?? 0) >= target($0) }) }
            let t = climbsPer.with { c -> CampaignTarget in
                let t = targets.min { (full.contains($0) ? 1 : 0, c[$0] ?? 0) < (full.contains($1) ? 1 : 0, c[$1] ?? 0) }!
                c[t, default: 0] += 1
                return t
            }
            // Seeds: a bank puzzle, a fresh sparse puzzle, or one of the best found so far (to climb further).
            let seeds = bankSeeds[t.chapter.id] ?? []
            let carried = seedElites[t] ?? []
            let elites = found.with { f in
                ((f[t] ?? [:]).values + carried).sorted { $0.score > $1.score }.prefix(eliteCount).map(\.puzzle)
            }
            // With carried-over elites, climb from them half the time; fresh seeds keep the variety.
            let roll = Int.random(in: 0..<(carried.isEmpty ? 3 : 4), using: &rng)
            let start: Grid
            if roll == 0 || roll == 3, let e = elites.randomElement(using: &rng) { start = e }
            else if roll == 1, let b = seeds.randomElement(using: &rng) { start = b }
            else { start = CampaignMiner.sparse(t, using: &rng) }
            climbs.with { $0 += 1 }
            if let m = CampaignMiner.climb(from: start, t, iterations: iterations, deadline: deadline, using: &rng) {
                record(m, t)
            }
        }
    }
    // Everything found, best first per target: `campaign-merge` picks the bundled pools from it,
    // and the rest is kept as an archive.
    let all = found.with { $0 }
    var out: [CampaignPuzzle] = []
    for t in targets {
        let list = (all[t] ?? [:]).values.sorted { $0.score > $1.score }
        out += list.map { CampaignMiner.bundle($0, t) }
        let uses = list.map(\.analysis.uses).sorted()
        let summary = uses.isEmpty ? "none" : "max \(uses.last!) median \(uses[uses.count / 2]) min \(uses.first!)"
        FileHandle.standardError.write("\(t): \(list.count) found; uses \(summary)\n".data(using: .utf8)!)
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    for p in out { print(String(decoding: try encoder.encode(p), as: UTF8.self)) }
    FileHandle.standardError.write("\(out.count) puzzles from \(climbs.with { $0 }) climbs in \(Int(Date().timeIntervalSince(start)))s\n".data(using: .utf8)!)

case "campaign-chapters":
    struct Info: Encodable { var id: String; var title: String; var part: Int; var partName: String; var family: [String] }
    let list = CampaignChapter.all.map {
        Info(id: $0.id, title: $0.title, part: $0.part, partName: CampaignChapter.parts[$0.part - 1], family: $0.family.map(\.name))
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    print(String(decoding: try encoder.encode(list), as: UTF8.self))

case "campaign-merge":
    // Picks the bundled campaign from mined files (JSON lines from `campaign`): the best puzzles
    // per chapter, kind and spotlight member, never the same solution grid twice in a chapter.
    let per = Int(option("--per", in: args) ?? "") ?? 8
    let endlessCount = Int(option("--endless", in: args) ?? "") ?? 150
    let files = args.dropFirst().filter { !$0.hasPrefix("--") && Int($0) == nil }
    var pool: [CampaignPuzzle] = []
    let decoder = JSONDecoder()
    for path in files {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { fail("Can't read \(path)") }
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: CharacterSet(charactersIn: "[],"))
            guard !trimmed.isEmpty, let p = try? decoder.decode(CampaignPuzzle.self, from: Data(trimmed.utf8)) else { continue }
            if let ch = CampaignChapter.named(p.chapter), ch.capsClues(p.kind), p.clueCount > CampaignKind.maxClues { continue }
            pool.append(p)
        }
    }
    // Mid-solve starts count only what happens after the cut (older miners counted the whole
    // solve); a mixed puzzle that no longer mixes enough after it is dropped.
    let loaded = pool
    let recounted = Locked<[CampaignPuzzle]>([])
    DispatchQueue.concurrentPerform(iterations: loaded.count) { i in
        var p = loaded[i]
        if p.startsMidSolve {
            guard let ch = CampaignChapter.named(p.chapter), let a = p.analysis(), a.solved, a.uses >= 1 else { return }
            if p.kind == .mixed && a.outside.count < ch.mixedVariety { return }
            p.uses = a.uses
            p.outside = a.outside.sorted { $0.score < $1.score }
            p.totalScore = a.totalScore
        }
        recounted.with { $0.append(p) }
    }
    pool = recounted.with { $0 }
    // Any practice, mixed or boss puzzle also qualifies for endless (same techniques, from its
    // givens), which fills the endless pools of rare chapters.
    let extra = pool.filter { $0.kind != .spotlight && $0.kind != .endless }
    let asEndless = Locked<[CampaignPuzzle]>([])
    DispatchQueue.concurrentPerform(iterations: extra.count) { i in
        var p = extra[i]
        p.kind = .endless
        if p.startsMidSolve {
            p.values = nil
            p.candidates = nil
            guard let a = p.analysis(), a.solved, a.uses >= 1 else { return }
            p.uses = a.uses
            p.outside = a.outside.sorted { $0.score < $1.score }
            p.totalScore = a.totalScore
        }
        asEndless.with { $0.append(p) }
    }
    pool += asEndless.with { $0 }
    var out: [CampaignPuzzle] = []
    // The rarest kinds pick first, so the boss gets its best puzzle and endless takes what's left.
    // Each pool prefers solution grids not used elsewhere in the chapter (climbs from one seed
    // often qualify for several kinds), but only between puzzles with the same use count: another
    // givens of a used grid that uses the technique more still wins. The same givens never appear
    // twice in a chapter outside endless.
    let order: [CampaignKind] = [.boss, .mixed, .context, .spotlight, .endless]
    for ch in CampaignChapter.all {
        var usedGrids = Set<String>()
        var usedGivens = Set<String>()
        var picked: [CampaignKind: [CampaignPuzzle]] = [:]
        for kind in order where ch.kinds.contains(kind) {
            let members: [Technique?] = kind == .spotlight ? ch.family : [nil]
            let want = kind == .endless ? endlessCount : per
            for m in members {
                var seen = Set<String>()
                // Distinct givens, best first, with their solution grids.
                var candidates: [(p: CampaignPuzzle, grid: String)] = pool
                    .filter { $0.chapter == ch.id && $0.kind == kind && $0.member == m }
                    .sorted { $0.score > $1.score }
                    .filter { seen.insert($0.puzzle.string).inserted
                              && (kind == .endless || !usedGivens.contains($0.puzzle.string)) }
                    .compactMap { p in BruteForce.solution(p.puzzle).map { (p, $0.string) } }
                // A grid already used in the chapter counts a little less than one use, so a
                // fresh grid wins a tie but never beats a puzzle that uses the technique more.
                let reusePenalty = 0.9 * (kind.score(uses: 1, outside: 0, totalScore: 0) - kind.score(uses: 0, outside: 0, totalScore: 0))
                var chosen: [CampaignPuzzle] = []
                while chosen.count < want, !candidates.isEmpty {
                    var best = 0, bestScore = -Double.infinity
                    for (i, c) in candidates.enumerated() {
                        let s = c.p.score - (usedGrids.contains(c.grid) ? reusePenalty : 0)
                        if s > bestScore { best = i; bestScore = s }
                        // Sorted by score, so nothing later can beat a fresh grid.
                        if !usedGrids.contains(c.grid) { break }
                    }
                    let c = candidates.remove(at: best)
                    usedGrids.insert(c.grid)
                    chosen.append(c.p)
                }
                if kind != .endless { usedGivens.formUnion(chosen.map(\.puzzle.string)) }
                // The boss leads with its hardest; the others play easiest first.
                if kind != .boss { chosen.sort { $0.totalScore < $1.totalScore } }
                picked[kind, default: []] += chosen
            }
        }
        for kind in CampaignKind.allCases { out += picked[kind] ?? [] }
        let summary = CampaignKind.allCases.compactMap { k in
            picked[k].map { list in "\(k.rawValue) \(list.count) (uses \(list.map(\.uses).max() ?? 0) max)" }
        }
        FileHandle.standardError.write("\(ch.id): \(summary.joined(separator: ", "))\n".data(using: .utf8)!)
    }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let lines = try out.map { String(decoding: try encoder.encode($0), as: UTF8.self) }
    print("[\n" + lines.joined(separator: ",\n") + "\n]")

case "drills":
    let per = Int(option("--per", in: args) ?? "") ?? 20
    let minutes = Double(option("--minutes", in: args) ?? "") ?? 10
    let seed = UInt64(option("--seed", in: args) ?? "") ?? UInt64.random(in: 0...UInt64.max)
    let threads = Int(option("--threads", in: args) ?? "") ?? ProcessInfo.processInfo.activeProcessorCount
    let only = option("--technique", in: args).map { list -> Set<Technique> in
        Set(list.split(separator: ",").map { name in
            guard let t = Technique(rawValue: String(name)) else { fail("Unknown technique \(name)") }
            return t
        })
    }
    let wanted: Set<Technique> = only ?? Set(Technique.allCases.filter { $0 != .bruteForce })
    let found = Locked<[Technique: [Drill]]>([:])
    let attempts = Locked(0)
    let start = Date()
    let deadline = start.addingTimeInterval(minutes * 60)
    if let path = option("--from", in: args) {
        guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { fail("Can't read \(path)") }
        let puzzles = text.split(separator: "\n").compactMap { Grid(String($0.split(separator: "\t").first ?? "")) }
        DispatchQueue.concurrentPerform(iterations: puzzles.count) { i in
            var rng = SplitMix64(seed: seed ^ UInt64(i))
            guard let solution = BruteForce.solution(puzzles[i]) else { return }
            attempts.with { $0 += 1 }
            // Several passes pick different occurrences of the same technique in one solve.
            for _ in 0..<4 {
                let drills = Drill.mine(puzzles[i], solution: solution, wanted: wanted, using: &rng)
                found.with { f in
                    for d in drills where (f[d.technique]?.count ?? 0) < per && !(f[d.technique] ?? []).contains(d) {
                        f[d.technique, default: []].append(d)
                    }
                }
            }
        }
    } else {
        DispatchQueue.concurrentPerform(iterations: threads) { worker in
            var mixer = SplitMix64(seed: seed ^ (UInt64(worker) &* 0xD1B5_4A32_D192_ED03))
            var rng = SplitMix64(seed: mixer.next())
            let solver = HumanSolver()
            while Date() < deadline {
                let missing = found.with { f in wanted.filter { (f[$0]?.count ?? 0) < per } }
                if missing.isEmpty { break }
                let (p, s) = Generator.makePuzzle(using: &rng)
                let n = attempts.with { $0 += 1; return $0 }
                let drills = Drill.mine(p, solution: s, wanted: missing, solver: solver, using: &rng)
                found.with { f in
                    for d in drills where (f[d.technique]?.count ?? 0) < per { f[d.technique, default: []].append(d) }
                }
                if n % 2000 == 0 {
                    let short = found.with { f in wanted.filter { (f[$0]?.count ?? 0) < per }.map { "\($0.rawValue)=\(f[$0]?.count ?? 0)" } }
                    FileHandle.standardError.write("\(n) puzzles, \(Int(Date().timeIntervalSince(start)))s; short: \(short.sorted().joined(separator: " "))\n".data(using: .utf8)!)
                }
            }
        }
    }
    let all = found.with { $0 }
    let list = wanted.sorted { $0.score < $1.score }.flatMap { all[$0] ?? [] }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    // One drill per line keeps diffs of the bundled file readable.
    let lines = try list.map { String(decoding: try encoder.encode($0), as: UTF8.self) }
    print("[\n" + lines.joined(separator: ",\n") + "\n]")
    FileHandle.standardError.write("\(list.count) drills from \(attempts.with { $0 }) puzzles in \(Int(Date().timeIntervalSince(start)))s\n".data(using: .utf8)!)
    for t in wanted.sorted(by: { $0.score < $1.score }) where (all[t]?.count ?? 0) < per {
        FileHandle.standardError.write("  short: \(t.rawValue) \(all[t]?.count ?? 0)/\(per)\n".data(using: .utf8)!)
    }

default:
    print(usage)
}
