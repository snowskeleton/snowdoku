import GameKit
import Observation
import SudokuCore
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Game Center: signs in quietly at launch and reports campaign achievements, the chapters
/// leaderboard and daily times. Everything works without it.
///
/// The achievements and leaderboards themselves are configured in App Store Connect from
/// `Design/achievements/GameCenter.json` (identifiers, titles, points, badge art). Reports are
/// idempotent, so after signing in everything is re-reported from local progress, which also
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

    /// Identifiers, as in `Design/achievements/GameCenter.json`.
    enum ID {
        static func chapter(_ ch: CampaignChapter) -> String { "snowdoku.chapter.\(ch.id)" }
        static func part(_ n: Int) -> String { "snowdoku.part.\(n)" }
        static let campaignComplete = "snowdoku.campaign.complete"
        static func bossSkip(_ ch: CampaignChapter) -> String { "snowdoku.boss.\(ch.id).skip" }
        static let chaptersLeaderboard = "snowdoku.chapters"
        static let dailyLeaderboard = "snowdoku.daily"
        static let chapterActivity = "snowdoku.activity.chapter"
        static let dailyActivity = "snowdoku.activity.daily"
    }

    private weak var campaign: CampaignProgress?

    func start(campaign: CampaignProgress) {
        self.campaign = campaign
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

    /// Chapter progress (percent of its steps), parts, the whole campaign, boss skips, and the
    /// chapters leaderboard.
    func reportCampaign(_ progress: CampaignProgress) {
        var achievements: [GKAchievement] = []
        func add(_ id: String, _ fraction: Double) {
            let a = GKAchievement(identifier: id)
            a.percentComplete = min(100, fraction * 100)
            a.showsCompletionBanner = fraction >= 1
            achievements.append(a)
        }
        let chapters = CampaignChapter.all
        for ch in chapters {
            add(ID.chapter(ch), progress.fraction(ch))
            if progress.skippedChapter(ch) { add(ID.bossSkip(ch), 1) }
        }
        for (i, _) in CampaignChapter.parts.enumerated() {
            let inPart = chapters.filter { $0.part == i + 1 }
            guard !inPart.isEmpty else { continue }
            add(ID.part(i + 1), Double(inPart.filter(progress.isComplete).count) / Double(inPart.count))
        }
        let done = progress.completedChapters
        add(ID.campaignComplete, Double(done) / Double(chapters.count))

        log("report \(achievements.filter { $0.percentComplete > 0 }.map { "\($0.identifier) \(Int($0.percentComplete))%" }.joined(separator: ", ")); chapters \(done)")
        guard isAuthenticated else { return }
        Task {
            do {
                try await GKAchievement.report(achievements)
                try await GKLeaderboard.submitScore(done, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [ID.chaptersLeaderboard])
            } catch {
                log("report failed: \(error.localizedDescription)")
            }
        }
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
