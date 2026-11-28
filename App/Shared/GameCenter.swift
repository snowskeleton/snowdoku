import GameKit
import Observation
import SudokuCore
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Game Center: signs in quietly at launch and reports achievements (campaign parts, dailies, solve
/// counts per tier, drills and the hidden digit runs), the chapters leaderboard and daily times.
/// Everything works without it.
///
/// The achievements and leaderboards themselves are configured in App Store Connect from
/// `Design/achievements/GameCenter.json`, generated from `Achievements.tsv` (identifiers, titles,
/// points, badge art). Reports are idempotent and Game Center keeps each achievement's best
/// percentage, so after signing in everything is re-reported from local progress, which also
/// covers progress made offline or before signing in.
@Observable @MainActor
final class GameCenter: NSObject {
    static let shared = GameCenter()

    private(set) var isAuthenticated = false
    /// A Game Center activity the player chose to play (iOS/macOS 26), for `RootView` to open.
    var requestedActivity: Activity?

    enum Activity: Equatable {
        case chapter(String)
        case daily
    }

    /// Identifiers, as in `Design/achievements/Achievements.tsv`.
    enum ID {
        static func part(_ n: Int) -> String { "snowdoku.part.\(n)" }
        static let campaignComplete = "snowdoku.campaign.complete"
        static let firstDaily = "snowdoku.daily.first"
        static func dailyStreak(_ days: Int) -> String { "snowdoku.daily.streak\(days)" }
        static func firstSolve(_ d: Difficulty) -> String { "snowdoku.solve.first.\(d.name.lowercased())" }
        static let everyTier = "snowdoku.solve.everyTier"
        static func solved(_ d: Difficulty, _ n: Int) -> String { "snowdoku.solve.\(d.name.lowercased()).\(n)" }
        static func digitFirst(_ d: Int) -> String { "snowdoku.secret.first.\(d)" }
        static let allDrills = "snowdoku.drills.all"
        static let chaptersLeaderboard = "snowdoku.chapters"
        static let dailyLeaderboard = "snowdoku.daily"
        static let chapterActivity = "snowdoku.activity.chapter"
        static let dailyActivity = "snowdoku.activity.daily"
    }

    static let streaks = [7, 30, 365]
    static let solveCounts = [10, 50, 100, 250, 500]

    private weak var campaign: CampaignProgress?
    private weak var stats: StatsStore?

    func start(campaign: CampaignProgress, stats: StatsStore) {
        self.campaign = campaign
        self.stats = stats
        #if DEBUG
        // UI tests and screenshots run without a Game Center account.
        if ProcessInfo.processInfo.arguments.contains(where: { ["-puzzle", "-demo", "-drill", "-campaign", "-technique", "-resetGames", "-resetCampaign"].contains($0) }) { return }
        #endif
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            MainActor.assumeIsolated {
                if let viewController {
                    // Debug builds stay quiet (simulators and UI tests have no account).
                    #if !DEBUG
                    self?.presentSignIn(viewController)
                    #else
                    _ = viewController
                    #endif
                    return
                }
                self?.authenticated(GKLocalPlayer.local.isAuthenticated, error: error)
            }
        }
    }

    private func authenticated(_ ok: Bool, error: Error?) {
        isAuthenticated = ok
        guard ok else {
            log("not signed in: \(error?.localizedDescription ?? "no player")")
            return
        }
        if #available(iOS 26, macOS 26, *) { GKLocalPlayer.local.register(GameActivityListener.shared) }
        if let campaign { reportCampaign(campaign) }
        if let stats { reportStats(stats) }
    }

    #if os(iOS)
    private func presentSignIn(_ vc: UIViewController) {
        let root = UIApplication.shared.connectedScenes.compactMap { ($0 as? UIWindowScene)?.keyWindow?.rootViewController }.first
        var top = root
        while let next = top?.presentedViewController { top = next }
        top?.present(vc, animated: true)
    }
    #else
    private func presentSignIn(_ vc: NSViewController) {
        (NSApp.keyWindow ?? NSApp.windows.first)?.contentViewController?.presentAsSheet(vc)
    }
    #endif

    // MARK: Reporting

    private func achievement(_ id: String, _ fraction: Double) -> GKAchievement {
        let a = GKAchievement(identifier: id)
        a.percentComplete = min(100, fraction * 100)
        a.showsCompletionBanner = fraction >= 1
        return a
    }

    private func report(_ achievements: [GKAchievement], leaderboard: (String, Int)? = nil) {
        log("report \(achievements.filter { $0.percentComplete > 0 }.map { "\($0.identifier) \(Int($0.percentComplete))%" }.joined(separator: ", "))")
        guard isAuthenticated else { return }
        Task {
            do {
                try await GKAchievement.report(achievements)
                if let (id, score) = leaderboard {
                    try await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [id])
                }
            } catch {
                log("report failed: \(error.localizedDescription)")
            }
        }
    }

    /// Parts (share of their chapters finished), the whole campaign, and the chapters leaderboard.
    func reportCampaign(_ progress: CampaignProgress) {
        let chapters = CampaignChapter.all
        var achievements: [GKAchievement] = []
        for n in 1...CampaignChapter.parts.count {
            let inPart = chapters.filter { $0.part == n }
            guard !inPart.isEmpty else { continue }
            achievements.append(achievement(ID.part(n), Double(inPart.filter(progress.isComplete).count) / Double(inPart.count)))
        }
        let done = progress.completedChapters
        achievements.append(achievement(ID.campaignComplete, Double(done) / Double(chapters.count)))
        report(achievements, leaderboard: (ID.chaptersLeaderboard, done))
    }

    /// Dailies and streaks, first solves and solve counts per tier (Free Play and dailies), drills,
    /// and the hidden digit runs, all from the saved statistics.
    func reportStats(_ store: StatsStore) {
        let s = store.stats
        var achievements = [achievement(ID.firstDaily, s.dailyCompleted.isEmpty ? 0 : 1)]
        for days in Self.streaks { achievements.append(achievement(ID.dailyStreak(days), Double(s.streak) / Double(days))) }
        for d in Difficulty.allCases {
            let solved = s.completed[d] ?? 0
            achievements.append(achievement(ID.firstSolve(d), solved > 0 ? 1 : 0))
            guard d > .beginner else { continue }
            for n in Self.solveCounts { achievements.append(achievement(ID.solved(d, n), Double(solved) / Double(n))) }
        }
        let tiers = Difficulty.allCases.filter { $0 <= .master }
        achievements.append(achievement(ID.everyTier, Double(tiers.filter { (s.completed[$0] ?? 0) > 0 }.count) / Double(tiers.count)))
        let drillable = Technique.allCases.filter(DrillBank.hasDrills)
        if !drillable.isEmpty {
            achievements.append(achievement(ID.allDrills, Double(drillable.filter(s.drilled.contains).count) / Double(drillable.count)))
        }
        // Hidden achievements are reported only once earned.
        for d in s.digitsFirst.sorted() { achievements.append(achievement(ID.digitFirst(d), 1)) }
        report(achievements)
    }

    /// A daily solved without hints: its time in whole seconds (the recurring daily leaderboard
    /// keeps each player's best of the day).
    func reportDaily(seconds: Double) {
        let score = max(1, Int(seconds.rounded()))
        log("report daily \(score)s")
        guard isAuthenticated else { return }
        Task {
            do {
                try await GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [ID.dailyLeaderboard])
            } catch {
                log("daily report failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Dashboard

    /// Shows the Game Center access point (on the Play home only).
    func showAccessPoint(_ show: Bool) {
        // Touching the access point creates its overlay, so leave it alone until signed in.
        guard isAuthenticated else { return }
        GKAccessPoint.shared.location = .topTrailing
        GKAccessPoint.shared.isActive = show && isAuthenticated
    }

    private func log(_ message: String) {
        #if DEBUG
        print("GameCenter: \(message)")
        #endif
    }
}

/// Receives Game Center activity requests (iOS/macOS 26) and hands them to `GameCenter`.
@available(iOS 26, macOS 26, *)
final class GameActivityListener: NSObject, GKLocalPlayerListener, @unchecked Sendable {
    static let shared = GameActivityListener()

    /// A friend's invitation or the Games app asked to play an activity: a campaign chapter or
    /// today's daily.
    func player(_ player: GKPlayer, wantsToPlay activity: GKGameActivity, completionHandler: @escaping (Bool) -> Void) {
        let request: GameCenter.Activity? = switch activity.activityDefinition.identifier {
        case GameCenter.ID.dailyActivity: .daily
        case GameCenter.ID.chapterActivity:
            .chapter(activity.properties["chapter"].flatMap(CampaignChapter.named)?.id ?? CampaignChapter.all[0].id)
        default: nil
        }
        completionHandler(request != nil)
        guard let request else { return }
        Task { @MainActor in GameCenter.shared.requestedActivity = request }
    }
}
