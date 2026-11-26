import SudokuCore

extension Technique {
    /// Techniques a player can learn (brute force isn't one), grouped by tier. Computed once.
    static let library: [Difficulty: [Technique]] = Dictionary(
        grouping: allCases.filter { $0 != .bruteForce }, by: \.difficulty
    )

    /// "Pointing, Claiming, Naked Pair and Hidden Pair": a taste of what a tier needs.
    static let tierBlurbs: [Difficulty: String] = library.mapValues {
        $0.prefix(4).map(\.name).formatted()
    }
}
