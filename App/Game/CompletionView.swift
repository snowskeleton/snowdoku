import SwiftUI
import SudokuCore

struct CompletionView: View {
    let game: Game
    @Environment(GameStore.self) private var store
    @Environment(CampaignProgress.self) private var campaign

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: headlineIcon).font(.system(size: 48)).foregroundStyle(headlineColor)
            Text(headline).font(.largeTitle.bold()).multilineTextAlignment(.center)
            Text("\(subtitle) · \(formatTime(game.elapsed()))")
                .foregroundStyle(.secondary)
            if game.hintsUsed > 0 || game.mistakes > 0 {
                Text("^[\(game.hintsUsed) hint](inflect: true) · ^[\(game.mistakes) mistake](inflect: true)")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let note = campaignNote {
                Text(note).font(.callout).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !advancedTechniques.isEmpty {
                Text("Techniques: \(advancedTechniques.map(\.name).formatted())")
                    .font(.footnote).multilineTextAlignment(.center).foregroundStyle(.secondary)
            }
            HStack {
                Button(game.campaign == nil ? "Home" : "Back", action: store.leaveGame).buttonStyle(.bordered)
                Button(nextTitle, action: nextPuzzle).buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
        .padding()
    }

    var chapter: CampaignChapter? { game.campaign?.chapterInfo }
    var step: CampaignStep? { game.campaign?.step }
    /// A campaign level solved with hints doesn't count.
    var needsRetry: Bool { game.campaign != nil && step != .endless && game.hintsUsed > 0 }
    var finishedChapter: Bool { step == .boss && !needsRetry }

    var headline: String {
        if finishedChapter { return "Chapter complete!" }
        return "Solved!"
    }
    var headlineIcon: String { finishedChapter ? "crown.fill" : needsRetry ? "checkmark.circle" : "checkmark.seal.fill" }
    var headlineColor: Color { finishedChapter ? .orange : needsRetry ? .secondary : .green }

    var subtitle: String {
        if let ch = chapter, let step { return ch.title(for: step) }
        return game.levelName
    }

    var campaignNote: String? {
        guard let c = game.campaign, let ch = chapter else { return nil }
        if needsRetry { return "Solve one without hints to move on. The next try is a different puzzle." }
        let uses = game.focusUses
        let used = uses > 0 ? "You used \(c.focus.count == 1 ? c.focus.first!.name : ch.title) ^[\(uses) time](inflect: true)." : nil
        if finishedChapter, ch.index + 1 < CampaignChapter.all.count {
            return [used, "\(CampaignChapter.all[ch.index + 1].title) is open."].compactMap { $0 }.joined(separator: " ")
        }
        return used
    }

    var nextTitle: String {
        if game.drill != nil && game.campaign == nil { return "Next drill" }
        guard game.campaign != nil else { return "Next puzzle" }
        if needsRetry { return "Try another" }
        if step == .endless { return "Next puzzle" }
        if finishedChapter { return "Next chapter" }
        return "Next level"
    }

    /// Techniques worth calling out (every puzzle uses singles).
    var advancedTechniques: [Technique] {
        game.techniques.filter { $0.difficulty > .beginner }
    }

    func nextPuzzle() {
        if game.campaign != nil {
            guard let next = store.nextCampaignStep(after: game) else { store.leaveGame(); return }
            Task { await store.playCampaign(next.chapter, next.step) }
            return
        }
        if let t = game.drill?.technique {
            Task { await store.drill(t) }
            return
        }
        // After an "All" game, another from the whole tier.
        if case .freePlay(let d) = store.lastActivity, d == game.difficulty, game.dailyKey == nil, game.practice == nil {
            Task { await store.newGame(all: d) }
            return
        }
        let level = game.level ?? Level.highest(in: game.difficulty)
        Task { await store.newGame(GameStore.playableLevel(level)) }
    }
}
