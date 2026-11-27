import Foundation
import Testing
@testable import SudokuCore

@Suite struct SpotlightTests {
    static let drills: [Drill] = {
        let url = URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "../../../App/Resources/Drills.json").standardized
        let all = (try? JSONDecoder().decode([Drill].self, from: Data(contentsOf: url))) ?? []
        return all.filter { Spotlight.supports($0.technique) }
    }()

    /// Every singles drill, at every level and for every choice of target, gives a spotlight that
    /// accepts at least one instance, and every accepted instance lies inside it.
    @Test func everyDrillHasAnAnswer() throws {
        #expect(Self.drills.count >= 60)
        for d in Self.drills {
            let targets = d.targets()
            for level in SpotlightLevel.allCases {
                for i in targets.indices {
                    let s = try #require(Spotlight.make(d.technique, level: level, targets: targets, pick: { _ in i }))
                    let accepted = targets.filter(s.accepts)
                    #expect(!accepted.isEmpty, "\(d.technique) \(level): nothing to find")
                    #expect(accepted.allSatisfy { $0.placements.allSatisfy { s.cells.contains($0.cell) } })
                    #expect(!s.prompt.isEmpty)
                    if level == .exact { #expect(Set(accepted.flatMap(\.placements)).count == 1, "an exact question has one answer") }
                }
            }
        }
    }

    /// At the exact level, a wrong digit in the spotlight always breaks a visible rule (singles
    /// positions have no hidden eliminations), so the feedback can point at the clash.
    @Test func exactWrongAnswersShowTheirConflict() throws {
        for d in Self.drills {
            let solution = try #require(BruteForce.solution(d.puzzle))
            let b = d.board
            let s = try #require(Spotlight.make(d.technique, level: .exact, targets: d.targets()))
            let answer = try #require(d.targets().first(where: s.accepts)?.placements.first)
            for c in s.cells where b.values[c] == 0 {
                let digits = s.digit.map { [$0] } ?? Array(1...9)
                for digit in digits where !(c == answer.cell && digit == answer.digit) && solution[c] != digit {
                    let f = SpotlightFeedback.judge(digit: digit, at: c, board: b, solution: solution, asked: d.technique)
                    guard case let .conflict(dd, h, seen) = f else {
                        Issue.record("\(d.technique): \(digit) at \(Geometry.cellName(c)) gave \(f)"); continue
                    }
                    #expect(dd == digit && b.values[seen] == UInt8(digit) && Geometry.houseSets[h].contains(c))
                }
            }
        }
    }

    @Test func rightButOtherTechnique() throws {
        // A Full House drill usually has other singles around: placing one is right but not asked.
        var sawOther = false
        for d in Self.drills where d.technique == .fullHouse {
            let solution = try #require(BruteForce.solution(d.puzzle))
            let fullHouseCells = Set(d.targets().flatMap { $0.placements.map(\.cell) })
            for t in [Technique.hiddenSingleBox, .hiddenSingleLine, .nakedSingle] {
                for step in HumanSolver().allSteps(d.board, technique: t) {
                    let p = step.placements[0]
                    guard !fullHouseCells.contains(p.cell) else { continue }
                    let f = SpotlightFeedback.judge(digit: p.digit, at: p.cell, board: d.board, solution: solution, asked: .fullHouse)
                    guard case .otherTechnique(_, .fullHouse) = f else { Issue.record("got \(f)"); continue }
                    sawOther = true
                }
            }
        }
        #expect(sawOther)
    }

    @Test func survivesTransforms() throws {
        var rng = SplitMix64(seed: 7)
        for d in Self.drills.prefix(20) {
            let t = d.transformed(by: .random(using: &rng))
            let s = try #require(Spotlight.make(t.technique, level: .exact, targets: t.targets()))
            #expect(t.targets().contains(where: s.accepts))
        }
    }
}
