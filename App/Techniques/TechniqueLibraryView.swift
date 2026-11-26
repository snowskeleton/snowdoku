import SwiftUI
import SudokuCore

struct TechniqueLibraryView: View {
    var body: some View {
        List {
            ForEach(Difficulty.allCases, id: \.self) { d in
                Section(d.name) {
                    ForEach(Technique.library[d] ?? [], id: \.self) { t in
                        NavigationLink(value: t) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(t.name)
                                Text(t.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Techniques")
        .navigationDestination(for: Technique.self, destination: TechniqueDetailView.init)
    }
}
