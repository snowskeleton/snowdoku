/// Families of techniques, for browsing. The grouping and order follow HoDoKu's technique pages,
/// except that Sue de Coq sits with the almost locked sets (it is two of them) rather than in a
/// one-item "Miscellaneous".
public enum TechniqueCategory: Int, CaseIterable, Codable, Sendable {
    case singles, intersections, subsets, basicFish, finnedFish, complexFish, singleDigitPatterns,
         uniqueness, wings, coloring, chains, almostLockedSets, lastResort

    public var name: String {
        switch self {
        case .singles: "Singles"
        case .intersections: "Intersections"
        case .subsets: "Subsets"
        case .basicFish: "Basic Fish"
        case .finnedFish: "Finned & Sashimi Fish"
        case .complexFish: "Complex Fish"
        case .singleDigitPatterns: "Single-Digit Patterns"
        case .uniqueness: "Uniqueness"
        case .wings: "Wings"
        case .coloring: "Coloring"
        case .chains: "Chains & Loops"
        case .almostLockedSets: "Almost Locked Sets"
        case .lastResort: "Last Resort"
        }
    }

    /// One sentence on what the family has in common.
    public var summary: String {
        switch self {
        case .singles: "Placing a digit because a cell or a house leaves it only one option."
        case .intersections: "Where a box crosses a row or column, a digit locked into the overlap clears the rest of one house."
        case .subsets: "N cells in a house that share N digits between them, so those digits go nowhere else."
        case .basicFish: "One digit confined to the same columns across several rows, or the reverse."
        case .finnedFish: "Fish that are almost perfect, with a few extra candidates in one box."
        case .complexFish: "Fish whose houses mix rows, columns and boxes."
        case .singleDigitPatterns: "Short chains of strong links on a single digit."
        case .uniqueness: "Deductions that rely on the puzzle having exactly one solution."
        case .wings: "A few bivalue or near-bivalue cells that force one digit into one of their wings."
        case .coloring: "Following a digit's strong links and splitting its candidates into two colors."
        case .chains: "Alternating strong and weak links across cells and digits."
        case .almostLockedSets: "Groups of N cells with N+1 digits, linked so that one of them has to lock."
        case .lastResort: "Trying a candidate and following every consequence."
        }
    }
}

extension Technique {
    public var category: TechniqueCategory {
        switch self {
        case .fullHouse, .hiddenSingleBox, .hiddenSingleLine, .nakedSingle: .singles
        case .pointing, .claiming, .lockedPair, .lockedTriple: .intersections
        case .nakedPair, .hiddenPair, .nakedTriple, .hiddenTriple, .nakedQuad, .hiddenQuad: .subsets
        case .xWing, .swordfish, .jellyfish: .basicFish
        case .finnedXWing, .sashimiXWing, .finnedSwordfish, .sashimiSwordfish, .finnedJellyfish, .sashimiJellyfish: .finnedFish
        case .frankenFish, .mutantFish: .complexFish
        case .skyscraper, .twoStringKite, .turbotFish, .emptyRectangle: .singleDigitPatterns
        case .uniqueRectangle1, .uniqueRectangle2, .uniqueRectangle3, .uniqueRectangle4, .uniqueRectangle5, .uniqueRectangle6,
             .hiddenRectangle, .avoidableRectangle, .avoidableRectangle2, .bugPlusOne, .uniqueRectangleMissing: .uniqueness
        case .xyWing, .xyzWing, .wWing, .wxyzWing: .wings
        case .simpleColoring, .colorWrap, .multiColoring: .coloring
        case .remotePair, .xChain, .xyChain, .niceLoop, .discontinuousNiceLoop, .aic, .groupedAIC: .chains
        case .sueDeCoq, .alsXZ, .alsXYWing, .alsChain, .deathBlossom: .almostLockedSets
        case .krakenFish, .cellForcingChain, .unitForcingChain, .forcingContradiction, .forcingNet, .bruteForce: .lastResort
        }
    }
}
