import SwiftUI
import SudokuCore

/// The campaign path: parts, each a list of chapters. A chapter opens when the one before it
/// is finished (by beating its boss).
struct CampaignView: View {
    @Environment(CampaignProgress.self) private var progress

    var body: some View {
        List {
            ForEach(Array(CampaignChapter.parts.enumerated()), id: \.offset) { i, part in
                Section(part) {
                    ForEach(CampaignChapter.all.filter { $0.part == i + 1 }) { ch in
                        NavigationLink(value: PlayRoute.chapter(ch.id)) {
                            CampaignChapterRow(chapter: ch)
                        }
                        .disabled(!progress.isUnlocked(ch))
                    }
                }
            }
        }
        .navigationTitle("Campaign")
    }
}
