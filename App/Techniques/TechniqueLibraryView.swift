import SwiftUI
import SudokuCore

struct TechniqueLibraryView: View {
    @AppStorage("techniqueGrouping") private var grouping: TechniqueGrouping = .difficulty

    var body: some View {
        List {
            Section {
                Picker("Group techniques", selection: $grouping) {
                    ForEach(TechniqueGrouping.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            switch grouping {
            case .difficulty:
                ForEach(Difficulty.allCases, id: \.self) { d in
                    if let list = Technique.library[d] {
                        Section(d.name) {
                            ForEach(list, id: \.self) { TechniqueRow(technique: $0, showsDifficulty: false) }
                        }
                    }
                }
            case .category:
                ForEach(TechniqueCategory.allCases, id: \.self) { c in
                    if let list = Technique.libraryByCategory[c] {
                        Section {
                            ForEach(list, id: \.self) { TechniqueRow(technique: $0, showsDifficulty: true) }
                        } header: {
                            Text(c.name)
                        } footer: {
                            Text(c.summary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Techniques")
        .navigationDestination(for: Technique.self, destination: TechniqueDetailView.init)
    }
}
