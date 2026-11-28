import SwiftUI
import SudokuCore

/// A technique in the library: name and summary, plus its level ("Hard 2") when the list isn't grouped by level.
struct TechniqueRow: View {
    let technique: Technique
    let showsDifficulty: Bool

    var body: some View {
        NavigationLink(value: technique) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(technique.name)
                    Spacer(minLength: 8)
                    if showsDifficulty {
                        Text(technique.level.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text(technique.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
        }
    }
}
