import SwiftUI
import SudokuCore

/// One chapter: its lessons, then its steps in order.
struct ChapterView: View {
    let chapter: CampaignChapter
    @Environment(GameStore.self) private var store
    @Environment(CampaignProgress.self) private var progress

    var body: some View {
        List {
            Section {
                Text(chapter.lead.summary)
                    .font(.subheadline)
                ForEach(chapter.family, id: \.self) { t in
                    NavigationLink {
                        TechniqueDetailView(technique: t)
                    } label: {
                        Label("Lesson: \(t.name)", systemImage: "book")
                    }
                }
            }
            Section("Levels") {
                ForEach(chapter.steps, id: \.self) { step in
                    Button { Task { await store.playCampaign(chapter, step) } } label: {
                        CampaignStepRow(chapter: chapter, step: step)
                    }
                    .disabled(!progress.isUnlocked(chapter, step))
                }
            }
        }
        .navigationTitle(chapter.title)
    }
}
