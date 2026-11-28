import Testing
@testable import SudokuCore

@Suite struct LevelTests {
    @Test func everyTechniqueHasOneLevel() {
        let listed = Level.allCases.flatMap(\.newTechniques)
        #expect(listed.count == Set(listed).count)
        #expect(Set(listed) == Set(Technique.allCases))
        #expect(Level.extreme.techniques == Set(Technique.allCases))
        #expect(HumanSolver.allStrategies.count == Technique.allCases.count - 1, "every technique but trial and error has a strategy")
        #expect(Set(HumanSolver.allStrategies.map(\.technique)).count == HumanSolver.allStrategies.count)
    }

    /// At most three techniques per level, counting pure variants as one.
    @Test func atMostThreeNewTechniques() {
        let variants: [Technique: Technique] = [.sashimiXWing: .finnedXWing, .sashimiSwordfish: .finnedSwordfish,
                                                .sashimiJellyfish: .finnedJellyfish, .lockedPair: .nakedPair,
                                                .lockedTriple: .nakedTriple, .uniqueRectangle5: .uniqueRectangle2]
        for l in Level.allCases where l != .extreme {
            let distinct = Set(l.newTechniques.map { variants[$0] ?? $0 })
            #expect(distinct.count <= 3, "\(l.name)")
        }
    }

    @Test func tiersAndNames() {
        #expect(Level.levels(in: .hard).count == 4 && Level.levels(in: .expert).count == 4 && Level.levels(in: .master).count == 3)
        #expect(Level.levels(in: .extreme) == [.extreme])
        #expect(Level.medium3.name == "Medium 3" && Level.extreme.name == "Extreme")
        #expect(Daily.level(for: .medium) == .medium4)
        #expect(Technique.krakenFish.difficulty == .extreme && Technique.mutantFish.difficulty == .extreme)
        #expect(Technique.remotePair.level == .hard1 && Technique.finnedXWing.level == .medium1)
    }

    /// A plain X-Wing is found before a finned one, even though both are Medium 1.
    @Test func xWingBeforeFinnedXWing() {
        let order = HumanSolver.allStrategies.map(\.technique)
        #expect(order.firstIndex(of: .xWing)! < order.firstIndex(of: .finnedXWing)!)
        #expect(order.firstIndex(of: .nakedQuad)! < order.firstIndex(of: .skyscraper)!)
    }

    /// The rated level is the smallest level whose techniques solve the puzzle: the level below
    /// gets stuck, the level itself solves it.
    @Test func levelIsTheSmallestSolvingSet() {
        var rng = SplitMix64(seed: 17)
        var checked = 0
        for _ in 0..<40 {
            let (p, s) = Generator.makePuzzle(using: &rng)
            let r = Rater.rate(p, solution: s)
            let l = r.techniqueLevel
            guard l != .extreme else { continue }
            let only = { (l: Level) in HumanSolver(allowing: l.techniques).solve(Board(p), limit: l) }
            #expect(only(l).solved, "\(p.string) at \(l.name)")
            if l > .beginner1, let below = Level.allCases.last(where: { $0 < l }) {
                #expect(!only(below).solved, "\(p.string) solves at \(below.name) but rated \(l.name)")
            }
            checked += 1
        }
        #expect(checked > 30)
    }

    /// Hints stay within the puzzle's level: the solver at that level never escalates on its own
    /// solve path.
    @Test func hintsStayWithinTheLevel() throws {
        var rng = SplitMix64(seed: 23)
        for _ in 0..<10 {
            let (p, s) = Generator.makePuzzle(using: &rng)
            let r = Rater.rate(p, solution: s)
            var values = p.cells
            for step in HumanSolver().solve(Board(p), solution: s).steps {
                for c in step.placements { values[c.cell] = UInt8(c.digit) }
                guard values.contains(0) else { break }
                if case .step(let h, _) = HintEngine.hint(values: values, notes: nil, givens: Board(p).givens,
                                                          solution: s, level: r.techniqueLevel) {
                    #expect(h.level <= r.techniqueLevel || h.technique == .bruteForce)
                }
            }
        }
    }

    @Test func bumpedPuzzlesLandOnTheNextTiersFirstLevel() {
        let r = Rating(hardest: .xWing, techniqueLevel: .medium1, totalScore: 5000, counts: [.xWing: 1], stepCount: 1)
        #expect(r.isBumped && r.level == .hard1 && r.difficulty == .hard)
        let m = Rating(hardest: .alsXZ, techniqueLevel: .master2, totalScore: 50000, counts: [.alsXZ: 1], stepCount: 1)
        #expect(!m.isBumped && m.level == .master2)
    }
}
