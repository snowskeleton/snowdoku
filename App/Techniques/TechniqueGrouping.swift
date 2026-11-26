/// How the technique library is organized.
enum TechniqueGrouping: String, CaseIterable, Identifiable {
    case difficulty, category

    var id: Self { self }

    var label: String {
        switch self {
        case .difficulty: "By difficulty"
        case .category: "By category"
        }
    }
}
