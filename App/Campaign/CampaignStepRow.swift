import SwiftUI
import SudokuCore

/// A step of a chapter: what it is, and whether it's done, open or locked.
struct CampaignStepRow: View {
    let chapter: CampaignChapter
    let step: CampaignStep
    @Environment(CampaignProgress.self) private var progress

    var body: some View {
        HStack(spacing: 12) {
            icon
                .font(.title3)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(chapter.title(for: step)).font(.headline)
                    .foregroundStyle(unlocked ? Color.primary : Color.secondary)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(done ? "Done" : unlocked ? "Open" : "Locked")
    }

    var unlocked: Bool { progress.isUnlocked(chapter, step) }
    var done: Bool { progress.isDone(chapter, step) }

    var detail: String {
        if step == .drills && !done { return "\(progress.cleanDrills(chapter)) of \(CampaignProgress.drillsNeeded) · \(chapter.subtitle(for: step))" }
        return chapter.subtitle(for: step)
    }

    @ViewBuilder var icon: some View {
        if done {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        } else if !unlocked {
            Image(systemName: "lock.fill").foregroundStyle(.secondary)
        } else {
            switch step {
            case .boss: Image(systemName: "crown.fill").foregroundStyle(.orange)
            case .drills: Image(systemName: "stopwatch").foregroundStyle(Color.accentColor)
            case .endless: Image(systemName: "infinity").foregroundStyle(Color.accentColor)
            default: Image(systemName: "play.circle.fill").foregroundStyle(Color.accentColor)
            }
        }
    }
}
