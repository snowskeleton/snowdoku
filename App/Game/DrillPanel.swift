import SwiftUI
import SudokuCore

/// Floats over the controls once the player makes the drill's move. In a campaign drill round
/// it also says whether the drill counted.
struct DrillPanel: View {
    let game: Game
    @Environment(GameStore.self) private var store
    @Environment(CampaignProgress.self) private var campaign

    var body: some View {
        if let drill = game.drill {
            VStack(alignment: .leading, spacing: 10) {
                Label(game.isLesson ? "That's it!" : "That's the \(drill.technique.name)!", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                if let round = roundNote {
                    Text(round).font(.subheadline.bold())
                }
                if let step = game.drillFoundStep {
                    Text(step.explanation)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Button("Keep solving", action: keepSolving)
                        .buttonStyle(.bordered)
                    Spacer()
                    Button(nextLabel, action: nextDrill)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .strokeBorder(Color.primary.opacity(0.08))
            }
            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        }
    }

    var chapter: CampaignChapter? { game.campaign?.step == .drills ? game.campaign?.chapterInfo : nil }
    var roundDone: Bool { chapter.map { campaign.isDone($0, .drills) } ?? false }

    /// The lesson round this question belongs to.
    var lesson: (chapter: CampaignChapter, index: Int)? {
        guard let c = game.campaign, case .lesson(let i) = c.step, let ch = c.chapterInfo else { return nil }
        return (ch, i)
    }
    var lessonDone: Bool { lesson.map { campaign.isDone($0.chapter, .lesson($0.index)) } ?? false }

    var nextLabel: String {
        if lesson != nil { return lessonDone ? "Continue" : "Next question" }
        return roundDone ? "On to the boss" : "Next drill"
    }

    var roundNote: String? {
        if let (ch, i) = lesson {
            let total = CampaignChapter.lessonLevels[i].count
            return lessonDone ? "Lesson done!" : "\(min(campaign.lessonAnswers(ch, i), total)) of \(total)."
        }
        guard let ch = chapter, let clean = game.campaignDrillClean else { return nil }
        let count = "\(min(campaign.cleanDrills(ch), CampaignProgress.drillsNeeded)) of \(CampaignProgress.drillsNeeded)"
        if roundDone { return "Drill round done (\(count))." }
        if clean { return "Clean! \(count)." }
        let why = game.hintsUsed > 0 ? "a hint" : game.mistakes > 0 ? "a wrong entry" : "too long"
        return "Doesn't count (\(why)). \(count)."
    }

    func keepSolving() {
        withAnimation { game.drillState = .dismissed }
        store.save()
    }

    func nextDrill() {
        if let (ch, i) = lesson {
            if lessonDone, let next = store.nextCampaignStep(after: game) {
                Task { await store.playCampaign(next.chapter, next.step) }
            } else {
                Task { await store.playCampaign(ch, .lesson(i)) }
            }
            return
        }
        if let ch = chapter {
            Task { await store.playCampaign(ch, roundDone ? .boss : .drills) }
            return
        }
        guard let t = game.drill?.technique else { return }
        Task { await store.drill(t) }
    }
}
