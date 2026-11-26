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
  sudokugen mutate --from FILE [--count N] [--minutes M]
                                           Find more extreme puzzles (ones that need forcing chains)
                                           by swapping clues in known ones (puzzles to stdout)
  sudokugen drills [options]               Mine "next move is X" training positions (JSON to stdout)
      --per N           drills per technique (default 20)
      --technique T     only this technique
      --minutes M       stop after M minutes even if some techniques are short (default 10)
      --from FILE       mine these puzzles (one per line) instead of random ones, each once
      --seed N, --threads N
  sudokugen bank [--per N] FILE...        Rate puzzles (first column of each line) into the bundled
                                           bank format, easiest tier first; drops duplicates, invalid
                                           puzzles and ones that need trial and error
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
    for l in lines where !l.trimmingCharacters(in: .whitespaces).isEmpty {
        let raw = String(l.split(separator: "\t").first ?? "")
        guard let g = Grid(raw), let r = Rater.rate(g) else { print("\(raw)\tINVALID"); continue }
        print("\(g.string)\t\(r.difficulty.name)\t\(r.hardest.rawValue)\t\(r.totalScore)\t\(r.techniques.map(\.rawValue).joined(separator: ","))")
    }

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
            let r = Rater.rate(p, solution: s, solver: solver)
            if let difficulty, r.difficulty != difficulty { continue }
            if let technique, r.counts[technique] == nil { continue }
            let gp = GeneratedPuzzle(puzzle: p, solution: s, rating: r)
            let emitted = results.with { list -> Bool in
                guard list.count < count, !list.contains(where: { $0.puzzle == gp.puzzle }) else { return false }
                list.append(gp)
                return true
            }
            if emitted && cmd == "generate" {
                let line = tsv(gp)
                results.with { _ in print(line); fflush(stdout) }
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
    let ranked = Locked<[Technique: [Drill]]>([:])
    let keys = Array(byTechnique.keys)
    DispatchQueue.concurrentPerform(iterations: keys.count) { i in
        let t = keys[i]
        // Simplest step first, then the fewest highlighted cells: that one becomes the worked example.
        let scored = byTechnique[t]!.compactMap { d in d.step().map { s in (d, s.complexity, s.patternCells.count) } }
        let sorted = scored.sorted { ($0.1, $0.2) < ($1.1, $1.2) }.map(\.0)
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
    let seeds = text.split(separator: "\n").compactMap { Grid(String($0.split(separator: "\t").first ?? "")) }
        .filter { BruteForce.hasUniqueSolution($0) && !nonForcing.solve(Board($0)).solved }
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
            if added { pool.with { _ in print(g.string); fflush(stdout) } }
        }
    }
    FileHandle.standardError.write("\(pool.with { $0.count } - seeds.count) new extreme puzzles from \(tries.with { $0 }) tries\n".data(using: .utf8)!)

case "drills":
    let per = Int(option("--per", in: args) ?? "") ?? 20
    let minutes = Double(option("--minutes", in: args) ?? "") ?? 10
    let seed = UInt64(option("--seed", in: args) ?? "") ?? UInt64.random(in: 0...UInt64.max)
    let threads = Int(option("--threads", in: args) ?? "") ?? ProcessInfo.processInfo.activeProcessorCount
    let only = option("--technique", in: args).map { name -> Technique in
        guard let t = Technique(rawValue: name) else { fail("Unknown technique") }
        return t
    }
    let wanted: Set<Technique> = only.map { [$0] } ?? Set(Technique.allCases.filter { $0 != .bruteForce })
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
