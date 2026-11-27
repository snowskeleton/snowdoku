import SwiftUI
import SudokuCore

struct TechniqueDetailView: View {
    let technique: Technique
    /// Off when opened from a hint mid-game, where starting another game would be a surprise.
    var showsPractice = true
    @Environment(GameStore.self) private var store

    var body: some View {
        List {
            Section {
                Text(technique.summary).font(.headline)
                LabeledContent("Difficulty", value: technique.difficulty.name)
                LabeledContent("Category", value: technique.category.name)
                if technique.assumesUniqueness {
                    Text("Relies on the puzzle having exactly one solution.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("How it works") {
                ForEach(Array(technique.guide.enumerated()), id: \.offset) { _, paragraph in
                    Text(LocalizedStringKey(paragraph))
                }
            }
            if let drill = DrillBank.example(for: technique) {
                Section("Example") {
                    TechniqueExample(drill: drill)
                }
            }
            if showsPractice { practiceSection }
        }
        .navigationTitle(technique.name)
    }

    var practiceSection: some View {
        Section {
            if DrillBank.hasDrills(for: technique) {
                Button("Drill: find the next move", systemImage: "scope", action: drill)
            }
            Button("Play a puzzle that needs it", systemImage: "graduationcap", action: practice)
        } header: {
            Text("Practice")
        } footer: {
            Text("A drill drops you into the middle of a puzzle where the very next move is \(technique.name). A full puzzle uses it somewhere along the way; ask for hints at the technique level to find it.")
        }
    }

    func drill() {
        Task { await store.drill(technique) }
    }

    func practice() {
        Task { await store.practice(technique) }
    }
}
