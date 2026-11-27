import SudokuCore

extension Technique {
    /// Techniques a player can learn (brute force isn't one), easiest first.
    static let learnable: [Technique] = allCases.filter { $0 != .bruteForce }.sorted { $0.score < $1.score }

    /// The learnable techniques by tier. Computed once.
    static let library: [Difficulty: [Technique]] = Dictionary(grouping: learnable, by: \.difficulty)

    /// The learnable techniques by family, easiest first within each. Computed once.
    static let libraryByCategory: [TechniqueCategory: [Technique]] = Dictionary(grouping: learnable, by: \.category)

    /// "Pointing, Claiming, Naked Pair and Hidden Pair": a taste of what a tier needs.
    static let tierBlurbs: [Difficulty: String] = library.mapValues {
        $0.prefix(4).map(\.name).formatted()
    }
}

extension Technique: @retroactive Identifiable {
    public var id: Self { self }
}
