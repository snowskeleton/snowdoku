import Foundation
import Observation
import SudokuCore

/// The player's way through the campaign, shared by every window and saved in `UserDefaults`.
///
/// Steps open in order. A puzzle step counts only when solved without hints; a hinted solve
/// marks that puzzle used, so the next try serves a different one. A chapter's boss is open as
/// soon as the chapter is, and beating it finishes the chapter (the skip).
@Observable @MainActor
final class CampaignProgress {
    struct State: Codable {
        /// "chapter/stepKey" of every step done.
        var completed: Set<String> = []
        /// Puzzle ids already served, by pool ("chapter/kind/member").
        var used: [String: Set<String>] = [:]
        /// Clean drills so far in each chapter's drill round.
        var cleanDrills: [String: Int] = [:]
        /// Chapters finished by beating the boss before any other step (optional, so saves
        /// from before it was added still decode).
        var skipped: Set<String>? = nil
    }

    /// Clean drills needed to finish a drill round.
    nonisolated static let drillsNeeded = 5

    /// Seconds a drill may take and still count, by the chapter's tier.
    nonisolated static func drillTimeLimit(_ d: Difficulty) -> Double {
        switch d {
        case .beginner: 30
        case .easy: 60
        case .medium: 90
        case .hard: 120
        default: 180
        }
    }

    private(set) var state = State()
    private let defaults = UserDefaults.standard
    private static let key = "campaign"

    init() {
        if let data = defaults.data(forKey: Self.key), let s = try? JSONDecoder().decode(State.self, from: data) {
            state = s
        }
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-resetCampaign") { state = State(); save() }
        // `-campaignDone <n>`: the first n chapters finished, for screenshots and tests.
        if let i = args.firstIndex(of: "-campaignDone"), i + 1 < args.count, let n = Int(args[i + 1]) {
            state = State()
            for ch in CampaignChapter.all.prefix(n) { for s in ch.steps where s != .endless { state.completed.insert(Self.key(ch, s)) } }
            save()
        }
        #endif
    }

    private func save() {
        if let data = try? JSONEncoder().encode(state) { defaults.set(data, forKey: Self.key) }
    }

    private static func key(_ ch: CampaignChapter, _ s: CampaignStep) -> String { "\(ch.id)/\(s.key)" }
    private static func poolKey(_ ch: CampaignChapter, _ s: CampaignStep) -> String {
        "\(ch.id)/\(s.kind?.rawValue ?? "")/\(ch.member(for: s)?.rawValue ?? "")"
    }

    // MARK: Queries

    func isDone(_ ch: CampaignChapter, _ s: CampaignStep) -> Bool { state.completed.contains(Self.key(ch, s)) }

    /// Finished by beating its boss.
    func isComplete(_ ch: CampaignChapter) -> Bool { isDone(ch, .boss) }

    func isUnlocked(_ ch: CampaignChapter) -> Bool {
        let i = ch.index
        return i == 0 || isComplete(CampaignChapter.all[i - 1])
    }

    func isUnlocked(_ ch: CampaignChapter, _ s: CampaignStep) -> Bool {
        guard isUnlocked(ch) else { return false }
        switch s {
        case .boss: return true
        case .endless: return isComplete(ch)
        default:
            if isComplete(ch) { return true }
            let steps = ch.steps
            guard let i = steps.firstIndex(of: s), i > 0 else { return true }
            return isDone(ch, steps[i - 1])
        }
    }

    /// Steps done out of the steps that count (everything but endless).
    func fraction(_ ch: CampaignChapter) -> Double {
        if isComplete(ch) { return 1 }
        let steps = ch.steps.filter { $0 != .endless }
        return Double(steps.filter { isDone(ch, $0) }.count) / Double(steps.count)
    }

    var completedChapters: Int { CampaignChapter.all.filter(isComplete).count }
    var hasStarted: Bool { !state.completed.isEmpty || !state.used.isEmpty }

    /// Where Continue goes: the first open, unfinished step of the first unfinished chapter
    /// (endless in the last chapter once everything is done).
    var nextStep: (chapter: CampaignChapter, step: CampaignStep)? {
        guard let ch = CampaignChapter.all.first(where: { !isComplete($0) }) else {
            return CampaignChapter.all.last.map { ($0, .endless) }
        }
        let s = ch.steps.first { isUnlocked(ch, $0) && !isDone(ch, $0) } ?? .boss
        return (ch, s)
    }

    func cleanDrills(_ ch: CampaignChapter) -> Int { state.cleanDrills[ch.id] ?? 0 }

    /// Finished by beating the boss without playing any of the chapter's other steps.
    func skippedChapter(_ ch: CampaignChapter) -> Bool { state.skipped?.contains(ch.id) ?? false }

    // MARK: Picking puzzles

    /// The step's own puzzle the first time; afterwards one not served yet (random), and once
    /// every puzzle in the pool has been served, any.
    func puzzle(_ ch: CampaignChapter, _ s: CampaignStep) -> CampaignPuzzle? {
        let pool = CampaignBank.pool(ch, s)
        guard !pool.isEmpty else { return nil }
        if s == .endless { return pool.randomElement() }
        let used = state.used[Self.poolKey(ch, s)] ?? []
        let own = pool[min(ch.canonicalIndex(for: s), pool.count - 1)]
        if !used.contains(own.puzzle.string) { return own }
        return pool.filter { !used.contains($0.puzzle.string) }.randomElement() ?? pool.randomElement()
    }

    // MARK: Recording

    func markUsed(_ ch: CampaignChapter, _ s: CampaignStep, id: String) {
        state.used[Self.poolKey(ch, s), default: []].insert(id)
        save()
    }

    func complete(_ ch: CampaignChapter, _ s: CampaignStep) {
        if s == .boss, !isComplete(ch), !ch.steps.contains(where: { $0 != .boss && isDone(ch, $0) }), cleanDrills(ch) == 0 {
            state.skipped = (state.skipped ?? []).union([ch.id])
        }
        state.completed.insert(Self.key(ch, s))
        save()
        GameCenter.shared.reportCampaign(self)
    }

    /// Counts a drill of the chapter's round; returns the clean count so far.
    @discardableResult
    func recordDrill(_ ch: CampaignChapter, clean: Bool) -> Int {
        guard clean else { return cleanDrills(ch) }
        let n = cleanDrills(ch) + 1
        state.cleanDrills[ch.id] = n
        if n >= Self.drillsNeeded { state.completed.insert(Self.key(ch, .drills)) }
        save()
        if n >= Self.drillsNeeded { GameCenter.shared.reportCampaign(self) }
        return n
    }
}
