import Foundation
import Observation
import SudokuCore

/// One window's game: the current puzzle, puzzle creation and its persistence.
/// Each window owns its own store, so two iPad or Mac windows can play different games.
/// Statistics are app-wide and live in `StatsStore`.
@Observable @MainActor
final class GameStore {
    var game: Game?
    var isPlaying = false
    var generating: String?
    var errorMessage: String?
    /// What Continue picks up (observable here; saved in `UserDefaults` for every window).
    var lastActivity: LastActivity? = LastActivity.current {
        didSet { LastActivity.current = lastActivity }
    }

    /// Levels offered for random games. Extreme puzzles are too rare to generate on device,
    /// so Extreme is offered only when the bundled bank has some.
    static let playable: [Difficulty] = Difficulty.allCases.filter { $0 < .extreme || PuzzleBank.hasPuzzles($0) }

    private let stats: StatsStore
    let campaign: CampaignProgress

    /// Unfinished games by `GameSlot.key`, as last saved by any window.
    private(set) var saved: [String: SavedGame]

    /// Restores the most recently played unfinished game. (Two windows opened on the same saved
    /// game play separate copies; whichever saves last is what Continue offers next time.)
    init(stats: StatsStore, campaign: CampaignProgress) {
        self.stats = stats
        self.campaign = campaign
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-resetGames") { SavedGames.store([:]); LastActivity.current = nil; lastActivity = nil }
        #endif
        saved = SavedGames.load()
        if let r = mostRecent?.record {
            game = Game(record: r)
            game?.pauseClock()
        }
    }

    /// The most recently played unfinished game, which Home offers to continue.
    var mostRecent: SavedGame? { saved.values.max { $0.savedAt < $1.savedAt } }

    /// The unfinished game in a slot, if there is one.
    func savedGame(_ slot: GameSlot) -> SavedGame? { saved[slot.key] }

    /// Saves the current game into its slot, or clears the slot once the game is finished.
    func save() {
        guard let g = game else { return }
        var all = SavedGames.load()
        if g.isComplete {
            if all[g.slot.key]?.record.id == g.id { all[g.slot.key] = nil }
        } else {
            all[g.slot.key] = SavedGame(record: g.record, savedAt: .now)
        }
        SavedGames.store(all)
        saved = all
    }

    /// Reloads the saved games, which another window may have changed.
    func reloadSaved() { saved = SavedGames.load() }

    /// Resumes the unfinished game in a slot: the one on screen if it's that game, else the saved one.
    func continueGame(_ slot: GameSlot) {
        if let g = game, g.slot == slot, !g.isComplete, saved[slot.key].map({ $0.record.id == g.id }) ?? true {
            resume(); return
        }
        guard let s = saved[slot.key] else { return }
        game = Game(record: s.record)
        isPlaying = true
        save()
        noteActivity(slot)
    }

    private func noteActivity(_ slot: GameSlot) {
        switch slot {
        case .campaign: lastActivity = .campaign
        case .random(let d): lastActivity = .freePlay(d)
        default: break
        }
    }

    func resume() {
        guard game != nil else { return }
        game?.resumeClock()
        isPlaying = true
    }

    /// Called when the board is dismissed, by the Home button or the navigation back button.
    func leaveGame() {
        game?.pauseClock()
        isPlaying = false
        save()
    }

    func recordCompletion(_ g: Game) {
        // Drills and campaign levels start mid-solve or are hand-picked, so their times and
        // results say nothing about solving skill at a tier.
        if g.drill == nil && g.campaign == nil { stats.recordCompletion(g) }
        if g.dailyKey != nil && g.hintsUsed == 0 { GameCenter.shared.reportDaily(seconds: g.elapsed()) }
        if g.campaign != nil && g.drill == nil { recordCampaignSolve(g) }
        save()
    }

    private func start(_ p: GeneratedPuzzle, dailyKey: String? = nil, practice: Technique? = nil) {
        game = Game(p, dailyKey: dailyKey, practice: practice)
        stats.recordStart(p.rating.difficulty)
        isPlaying = true
        save()
        if dailyKey == nil && practice == nil { lastActivity = .freePlay(p.rating.difficulty) }
    }

    /// Starts a specific puzzle (used by debug/test launch arguments; later by puzzle import).
    func start(puzzle: Grid) {
        guard case .unique(let solution) = BruteForce.analyze(puzzle) else { errorMessage = "That puzzle doesn't have a unique solution."; return }
        start(GeneratedPuzzle(puzzle: puzzle, solution: solution, rating: Rater.rate(puzzle, solution: solution)))
    }

    /// Serves a puzzle from the bundled bank, randomly transformed; generates one on device
    /// only if the bank has none for this level.
    func newGame(_ difficulty: Difficulty) async {
        if let p = PuzzleBank.random(difficulty) { start(p); return }
        generating = "Building a \(difficulty.name.lowercased()) puzzle…"
        defer { generating = nil }
        // Generation is CPU-heavy; keep it off the main actor.
        let p = await Task.detached(priority: .userInitiated) { () -> GeneratedPuzzle? in
            var rng = SystemRandomNumberGenerator()
            return Generator.generate(difficulty: difficulty, maxAttempts: 4000, using: &rng)
        }.value
        guard let p else { errorMessage = "Couldn't build a \(difficulty.name) puzzle. Try again."; return }
        start(p)
    }

    /// A puzzle that requires a specific technique, for practice from the technique library.
    func practice(_ technique: Technique) async {
        generating = "Finding a puzzle that needs \(technique.name)…"
        defer { generating = nil }
        let p = await Task.detached(priority: .userInitiated) { () -> GeneratedPuzzle? in
            var rng = SystemRandomNumberGenerator()
            return Generator.generate(requiring: technique, maxAttempts: 3000, using: &rng)
        }.value
        guard let p else { errorMessage = "\(technique.name) is rare. No puzzle found this time; try again."; return }
        start(p, practice: technique)
    }

    /// A position from the bundled drill bank where the next move is `technique`, randomly
    /// relabeled and reshuffled so repeats look fresh.
    func drill(_ technique: Technique) async {
        guard let d = DrillBank.random(for: technique) else {
            errorMessage = "There are no \(technique.name) drills yet."
            return
        }
        generating = "Setting up a \(technique.name) drill…"
        defer { generating = nil }
        let solution = await Task.detached(priority: .userInitiated) { BruteForce.solution(d.puzzle) }.value
        guard let solution else { errorMessage = "That drill is broken. Try another."; return }
        // Singles drills narrow to one area so they have a definite answer (see `Spotlight`).
        let spotlight = Spotlight.supports(technique) ? Self.spotlight(d, level: .area) : nil
        game = Game(drill: d, solution: solution, spotlight: spotlight)
        isPlaying = true
        save()
    }

    // MARK: Campaign

    /// Plays a campaign step: resumes it if it's the unfinished campaign game, else serves its
    /// next puzzle (randomly transformed) or, for the drill round, a drill.
    func playCampaign(_ ch: CampaignChapter, _ step: CampaignStep) async {
        lastActivity = .campaign
        if let s = savedGame(.campaign)?.record.campaign, s.chapter == ch.id, s.step == step {
            continueGame(.campaign); return
        }
        if step == .drills { await campaignDrill(ch); return }
        if case .lesson(let i) = step { await campaignLesson(ch, i); return }
        guard let p = campaign.puzzle(ch, step) else {
            errorMessage = "This level isn't available yet."
            return
        }
        var rng = SystemRandomNumberGenerator()
        let shown = p.transformed(by: .random(using: &rng))
        let solution = await Task.detached(priority: .userInitiated) { BruteForce.solution(shown.puzzle) }.value
        guard let solution else { errorMessage = "That level is broken. Try again."; return }
        let context = CampaignContext(chapter: ch.id, step: step, puzzleID: p.puzzle.string)
        game = Game(campaign: context, puzzle: shown, solution: solution)
        isPlaying = true
        save()
    }

    /// A drill for the chapter's drill round: a random family member that has drills.
    private func campaignDrill(_ ch: CampaignChapter) async {
        let members = ch.family.filter(DrillBank.hasDrills)
        guard let t = members.randomElement(), let d = DrillBank.random(for: t) else {
            // Nothing to drill: the round is a formality.
            for _ in 0..<CampaignProgress.drillsNeeded { campaign.recordDrill(ch, clean: true) }
            await playCampaign(ch, .boss)
            return
        }
        let solution = await Task.detached(priority: .userInitiated) { BruteForce.solution(d.puzzle) }.value
        guard let solution else { errorMessage = "That drill is broken. Try another."; return }
        let spotlight = ch.drillSpotlight.flatMap { Self.spotlight(d, level: $0) }
        game = Game(drill: d, solution: solution, campaign: CampaignContext(chapter: ch.id, step: .drills), spotlight: spotlight)
        isPlaying = true
        save()
    }

    /// The next question of a lesson round: a drill of the chapter's technique, spotlit at the
    /// round's level for this question.
    private func campaignLesson(_ ch: CampaignChapter, _ i: Int) async {
        let level = campaign.nextLessonLevel(ch, i)
        // The first lesson's opening questions go row, column, box when the position allows.
        let answered = campaign.lessonAnswers(ch, i)
        let kind: Geometry.HouseKind? = i == 0 && answered < 3 ? [.row, .column, .box][answered] : nil
        guard let d = DrillBank.random(for: ch.lead), let spotlight = Self.spotlight(d, level: level, prefer: kind) else {
            errorMessage = "This lesson isn't available yet."
            return
        }
        let solution = await Task.detached(priority: .userInitiated) { BruteForce.solution(d.puzzle) }.value
        guard let solution else { errorMessage = "That lesson is broken. Try again."; return }
        game = Game(drill: d, solution: solution, campaign: CampaignContext(chapter: ch.id, step: .lesson(i)), spotlight: spotlight)
        isPlaying = true
        save()
    }

    /// A spotlight on a random target of the drill, preferring one in a house of `prefer`.
    static func spotlight(_ d: Drill, level: SpotlightLevel, prefer kind: Geometry.HouseKind? = nil) -> Spotlight? {
        let targets = d.targets()
        let preferred = targets.indices.filter { i in kind.map { k in targets[i].houses.first.map { Geometry.kind($0) == k } ?? false } ?? true }
        let pool = preferred.isEmpty ? Array(targets.indices) : preferred
        guard let choice = pool.randomElement() else { return nil }
        return Spotlight.make(d.technique, level: level, targets: targets, pick: { _ in choice })
    }

    /// A campaign level is done when solved without hints; either way its puzzle has been served.
    private func recordCampaignSolve(_ g: Game) {
        guard let c = g.campaign, let ch = c.chapterInfo else { return }
        if let id = c.puzzleID { campaign.markUsed(ch, c.step, id: id) }
        if g.hintsUsed == 0 && c.step != .endless { campaign.complete(ch, c.step) }
    }

    /// Scores a drill of a drill round once its move is found: clean means no hint, no wrong
    /// entry and within the chapter's time limit.
    func recordCampaignDrill(_ g: Game) {
        if let c = g.campaign, case .lesson(let i) = c.step, let ch = c.chapterInfo, g.campaignDrillClean == nil {
            g.campaignDrillClean = true
            campaign.recordLesson(ch, i)
            save()
            return
        }
        guard let c = g.campaign, c.step == .drills, let ch = c.chapterInfo, g.campaignDrillClean == nil else { return }
        let clean = g.hintsUsed == 0 && g.mistakes == 0 && g.elapsed() <= CampaignProgress.drillTimeLimit(ch.lead.difficulty)
        g.campaignDrillClean = clean
        campaign.recordDrill(ch, clean: clean)
        save()
    }

    /// Where to go after a campaign game: the same step again after a hinted solve or a drill
    /// round still short, else the next open step (the next chapter's first once this one is done).
    func nextCampaignStep(after g: Game) -> (chapter: CampaignChapter, step: CampaignStep)? {
        guard let c = g.campaign, let ch = c.chapterInfo else { return nil }
        if c.step == .endless { return (ch, .endless) }
        if !campaign.isDone(ch, c.step) { return (ch, c.step) }
        if let s = ch.steps.first(where: { $0 != .endless && campaign.isUnlocked(ch, $0) && !campaign.isDone(ch, $0) }) {
            return (ch, s)
        }
        let i = ch.index
        if campaign.isComplete(ch), i + 1 < CampaignChapter.all.count {
            let next = CampaignChapter.all[i + 1]
            return (next, next.steps.first { !campaign.isDone(next, $0) } ?? .boss)
        }
        return (ch, .endless)
    }

    /// The Play tab's Continue: what it will do, and doing it.
    enum ContinueAction {
        case resume(SavedGame)
        case campaign(CampaignChapter, CampaignStep)
        case newGame(Difficulty)
    }

    var continueAction: ContinueAction? {
        switch lastActivity {
        case .campaign:
            if let s = savedGame(.campaign) { return .resume(s) }
            if let n = campaign.nextStep { return .campaign(n.chapter, n.step) }
        case .freePlay(let d):
            if let s = savedGame(.random(d)) { return .resume(s) }
            return .newGame(GameStore.playable.contains(d) ? d : .master)
        case nil:
            break
        }
        // Saves from before Continue knew the last activity.
        return mostRecent.map(ContinueAction.resume)
    }

    func performContinue() async {
        switch continueAction {
        case .resume(let s): continueGame(s.record.slot)
        case .campaign(let ch, let step): await playCampaign(ch, step)
        case .newGame(let d): await newGame(d)
        case nil: break
        }
    }

    func daily() async {
        let key = DailySchedule.key()
        if savedGame(.daily)?.record.dailyKey == key { continueGame(.daily); return }
        let difficulty = DailySchedule.difficulty()
        let seed = DailySchedule.seed()
        // From the bank, so the day's puzzle doesn't change when the generator does.
        if let p = PuzzleBank.daily(difficulty, seed: seed) { start(p, dailyKey: key); return }
        generating = "Preparing today's puzzle…"
        defer { generating = nil }
        let p = await Task.detached(priority: .userInitiated) { () -> GeneratedPuzzle? in
            var rng = SplitMix64(seed: seed)
            return Generator.generate(difficulty: difficulty, maxAttempts: 4000, using: &rng)
        }.value
        guard let p else { errorMessage = "Couldn't prepare today's puzzle."; return }
        start(p, dailyKey: key)
    }

    #if DEBUG
    /// Launch arguments run once per app launch (not per window).
    private static var appliedDebugArguments = false

    /// Screenshot/test hooks: `-puzzle <81> [-prefill n [-wrong]]`, `-demo <difficulty> [hintLevel] [-arm d]`,
    /// `-drill <technique> [-hint level]`.
    func applyDebugArguments() async {
        guard !Self.appliedDebugArguments else { return }
        Self.appliedDebugArguments = true
        let args = ProcessInfo.processInfo.arguments
        func value(after flag: String) -> String? {
            args.firstIndex(of: flag).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
        }
        #if os(macOS)
        // The Mac sidebar mounts the Play stack late and drops a push that's already
        // pending when it appears, so let the window settle first.
        try? await Task.sleep(for: .milliseconds(500))
        #endif
        if let p = value(after: "-puzzle"), let grid = Grid(p) {
            start(puzzle: grid)
            if let n = value(after: "-prefill").flatMap(Int.init) {
                game?.debugPrefill(leaving: n, wrong: args.contains("-wrong"))
            }
            return
        }
        if let id = value(after: "-campaign"), let ch = CampaignChapter.named(id) {
            let step = args.firstIndex(of: "-campaign").flatMap { $0 + 2 < args.count ? CampaignStep(key: args[$0 + 2]) : nil } ?? .spotlight(0)
            await playCampaign(ch, step)
            if let n = value(after: "-prefill").flatMap(Int.init) { game?.debugPrefill(leaving: n, wrong: false) }
            return
        }
        if let raw = value(after: "-drill"), let t = Technique(rawValue: raw) {
            await drill(t)
            if let level = value(after: "-hint").flatMap(Int.init) {
                for _ in 0...level { game?.requestHint() }
            }
            return
        }
        guard let name = value(after: "-demo"),
              let d = Difficulty.allCases.first(where: { $0.name.lowercased() == name }) else { return }
        await newGame(d)
        guard let g = game else { return }
        g.fillNotes()
        g.selected = g.values.firstIndex(of: 0)
        if let digit = value(after: "-arm").flatMap(Int.init) {
            g.selected = nil
            g.tapDigit(digit, small: false)
        }
        if let i = args.firstIndex(of: "-demo"), i + 2 < args.count, let level = Int(args[i + 2]) {
            for _ in 0...level { g.requestHint() }
        }
    }
    #endif
}
