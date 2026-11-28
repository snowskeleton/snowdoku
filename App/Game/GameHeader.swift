import SwiftUI
import SudokuCore

/// Difficulty, mistake count and timer above the board; in a drill, what to look for.
struct GameHeader: View {
    let game: Game
    @AppStorage("showTimer") private var showTimer = true
    @AppStorage("mistakeMode") private var mistakeMode: MistakeMode = .conflicts

    var body: some View {
        HStack {
            if let c = game.campaign, game.drill == nil, let ch = c.chapterInfo {
                Label(ch.title(for: c.step), systemImage: c.step == .boss ? "crown.fill" : "map")
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
                if game.focusUses > 0 {
                    Text("\(focusName(c)) ×\(game.focusUses)")
                        .foregroundStyle(Color.accentColor)
                        .contentTransition(.numericText())
                        .accessibilityLabel("\(focusName(c)) used \(game.focusUses) times")
                }
            } else if let drill = game.drill {
                Label(drillPrompt(drill), systemImage: game.drillState == .searching ? "scope" : "checkmark.circle.fill")
                    .foregroundStyle(game.drillState == .searching ? Color.primary : Color.green)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Spacer()
            } else {
                Label(game.levelName, systemImage: "chart.bar.fill")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            if mistakeMode == .solution {
                Label("\(game.mistakes)", systemImage: "xmark.circle")
                    .foregroundStyle(game.mistakes > 0 ? .red : .secondary)
            }
            if let limit = drillTimeLimit, game.drillState == .searching {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    let left = limit - game.elapsed(at: ctx.date)
                    Text(left >= 0 ? formatTime(left) : "Over time")
                        .monospacedDigit()
                        .foregroundStyle(left >= 0 ? Color.secondary : Color.orange)
                }
            } else if showTimer && game.drill == nil {
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text(formatTime(game.elapsed(at: ctx.date)))
                        .monospacedDigit()
                }
                .foregroundStyle(.secondary)
            }
        }
        .font(.subheadline)
    }

    /// In a campaign drill round, the time a drill may take and still count.
    var drillTimeLimit: Double? {
        guard let c = game.campaign, c.step == .drills, let ch = c.chapterInfo else { return nil }
        return CampaignProgress.drillTimeLimit(ch.lead.difficulty)
    }

    /// The technique a campaign level is about (the chapter's name for a whole family).
    func focusName(_ c: CampaignContext) -> String {
        c.focus.count == 1 ? c.focus.first!.name : c.chapterInfo?.title ?? ""
    }

    func drillPrompt(_ d: Drill) -> String {
        guard game.drillState == .searching else { return "Found: \(d.technique.name)" }
        return game.spotlight?.prompt ?? "Find the next move: \(d.technique.name)"
    }
}
