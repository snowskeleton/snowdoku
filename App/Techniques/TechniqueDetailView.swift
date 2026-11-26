import SwiftUI
import SudokuCore

struct TechniqueDetailView: View {
    let technique: Technique
    @Environment(GameStore.self) private var store

    var body: some View {
        List {
            Section {
                LabeledContent("Difficulty", value: technique.difficulty.name)
                LabeledContent("Score", value: "\(technique.score)")
                if technique.assumesUniqueness {
                    Text("Relies on the puzzle having exactly one solution.").font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("Idea") {
                Text(technique.summary)
            }
            Section {
                Button("Practice with a puzzle that needs it", systemImage: "graduationcap", action: practice)
            } footer: {
                Text("Generates a puzzle whose logical solution uses \(technique.name). Ask for hints at the technique level to find it.")
            }
        }
        .navigationTitle(technique.name)
    }

    func practice() {
        Task { await store.practice(technique) }
    }
}
