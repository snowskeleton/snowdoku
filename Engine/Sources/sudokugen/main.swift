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
      --coverage        instead, count the --bank puzzles that already qualify for each endless pool
      --seed N, --threads N
  sudokugen campaign-merge [--per N] [--endless N] FILE...
                                           Pick the bundled campaign from mined files: the best N per
                                           chapter, kind and spotlight member (default 8; endless 150)
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
            let elites = found.with { f in (f[t] ?? [:]).values.sorted { $0.score > $1.score }.prefix(10).map(\.puzzle) }
            let roll = Int.random(in: 0..<3, using: &rng)
            let start: Grid
            if roll == 0, let e = elites.randomElement(using: &rng) { start = e }
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
            if p.kind.capsClues && p.clueCount > CampaignKind.maxClues { continue }
            pool.append(p)
        }
    }
    var out: [CampaignPuzzle] = []
    // The rarest kinds pick first, so the boss gets its best puzzle and endless takes what's left.
    let order: [CampaignKind] = [.boss, .mixed, .context, .spotlight, .endless]
    for ch in CampaignChapter.all {
        var used = Set<String>()
        var picked: [CampaignKind: [CampaignPuzzle]] = [:]
        for kind in order where ch.kinds.contains(kind) {
            let members: [Technique?] = kind == .spotlight ? ch.family : [nil]
            for m in members {
                var candidates = pool.filter { $0.chapter == ch.id && $0.kind == kind && $0.member == m }
                candidates.sort { $0.score > $1.score }
                var chosen: [CampaignPuzzle] = []
                for p in candidates where chosen.count < (kind == .endless ? endlessCount : per) {
                    guard let sol = BruteForce.solution(p.puzzle), used.insert(sol.string).inserted else { continue }
                    chosen.append(p)
                }
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
