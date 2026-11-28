import SwiftUI
import SudokuCore

struct TechniqueLibraryView: View {
    @AppStorage("techniqueGrouping") private var grouping: TechniqueGrouping = .difficulty
    @State private var query = ""

    var body: some View {
        List {
            if query.trimmingCharacters(in: .whitespaces).isEmpty { grouped } else { results }
        }
        .navigationTitle("Techniques")
        #if os(iOS)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search techniques")
        #else
        .searchable(text: $query, prompt: "Search techniques")
        #endif
        .navigationDestination(for: Technique.self, destination: { TechniqueDetailView(technique: $0) })
    }

    /// Techniques whose name, summary or category match, name matches first.
    @ViewBuilder var results: some View {
        let q = query.trimmingCharacters(in: .whitespaces)
        let byName = Technique.learnable.filter { $0.name.localizedStandardContains(q) }
        let other = Technique.learnable.filter {
            !byName.contains($0) && ($0.summary.localizedStandardContains(q) || $0.category.name.localizedStandardContains(q))
        }
        if byName.isEmpty && other.isEmpty {
            ContentUnavailableView.search(text: q)
                .listRowBackground(Color.clear)
        } else {
            ForEach(byName + other, id: \.self) { TechniqueRow(technique: $0, showsDifficulty: true) }
        }
    }

    @ViewBuilder var grouped: some View {
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
            ForEach(Level.allCases, id: \.self) { level in
                if let list = Technique.libraryByLevel[level] {
                    Section(level.name) {
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
}
