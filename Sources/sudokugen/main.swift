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

default:
    print(usage)
}
