import SwiftUI
import SudokuCore

/// A chapter in the campaign list: number, title, tier and how far along it is.
struct CampaignChapterRow: View {
    let chapter: CampaignChapter
    @Environment(CampaignProgress.self) private var progress

    var body: some View {
        HStack(spacing: 12) {
            status
                .font(.title3)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(chapter.index + 1). \(chapter.title)").font(.headline)
                Text(chapter.lead.difficulty.name).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if progress.isUnlocked(chapter) && !progress.isComplete(chapter) && progress.fraction(chapter) > 0 {
                Gauge(value: progress.fraction(chapter)) {}
                    .gaugeStyle(.accessoryCircularCapacity)
                    .scaleEffect(0.5)
                    .frame(width: 28, height: 28)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(accessibilityStatus)
    }

    @ViewBuilder var status: some View {
        if progress.isComplete(chapter) {
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        } else if progress.isUnlocked(chapter) {
            Image(systemName: "circle.dashed").foregroundStyle(Color.accentColor)
        } else {
            Image(systemName: "lock.fill").foregroundStyle(.secondary)
        }
    }

    var accessibilityStatus: String {
        progress.isComplete(chapter) ? "Done" : progress.isUnlocked(chapter) ? "Open" : "Locked"
    }
}
