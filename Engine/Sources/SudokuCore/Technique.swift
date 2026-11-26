/// Difficulty tiers. A puzzle's tier is the tier of the hardest technique it needs, bumped up one
/// tier when the whole solve is unusually long for that tier (see `maxScore`).
public enum Difficulty: Int, Comparable, CaseIterable, Codable, Sendable {
    case beginner = 1, easy, medium, hard, expert, master, extreme

    public static func < (a: Difficulty, b: Difficulty) -> Bool { a.rawValue < b.rawValue }

    public var name: String {
        switch self {
        case .beginner: "Beginner"
        case .easy: "Easy"
        case .medium: "Medium"
        case .hard: "Hard"
        case .expert: "Expert"
        case .master: "Master"
        case .extreme: "Extreme"
        }
    }

    /// The largest total solve score (`Rating.totalScore`) a puzzle can have and still sit at this
    /// tier; above it, the puzzle is rated one tier harder. Set near the 98th percentile of random
    /// puzzles at each tier, around the median of the next tier, so a long, grinding solve
    /// counts as harder even when no single step is. Master is never bumped: Extreme means
    /// forcing chains.
    public var maxScore: Int? {
        switch self {
        case .beginner: 440
        case .easy: 750
        case .medium: 1050
        case .hard: 1600
        case .expert: 3200
        case .master, .extreme: nil
        }
    }
}

/// Every solving technique the engine knows. Raw values are stable identifiers (used in puzzle banks).
public enum Technique: String, CaseIterable, Codable, Sendable {
    // Singles
    case fullHouse, hiddenSingleBox, hiddenSingleLine, nakedSingle
    // Intersections & subsets
    case pointing, claiming
    case lockedPair, lockedTriple, nakedPair, hiddenPair, nakedTriple, hiddenTriple, nakedQuad, hiddenQuad
    // Fish
    case xWing, swordfish, jellyfish
    case finnedXWing, sashimiXWing, finnedSwordfish, sashimiSwordfish, finnedJellyfish, sashimiJellyfish
    // Single-digit patterns
    case skyscraper, twoStringKite, turbotFish, emptyRectangle
    // Wings
    case xyWing, xyzWing, wWing, wxyzWing
    // Uniqueness
    case uniqueRectangle1, uniqueRectangle2, uniqueRectangle3, uniqueRectangle4, uniqueRectangle5, uniqueRectangle6
    case hiddenRectangle, avoidableRectangle, avoidableRectangle2, bugPlusOne
    // Coloring
    case simpleColoring, colorWrap, multiColoring
    // Chains
    case remotePair, xChain, xyChain, niceLoop, discontinuousNiceLoop, aic, groupedAIC
    // Exotic fish
    case frankenFish, mutantFish, krakenFish
    // Almost locked sets
    case sueDeCoq, alsXZ, alsXYWing, alsChain, deathBlossom
    // Forcing
    case cellForcingChain, unitForcingChain, forcingContradiction, forcingNet
    // Last resort
    case bruteForce

    public var name: String {
        switch self {
        case .fullHouse: "Full House"
        case .hiddenSingleBox: "Hidden Single (Box)"
        case .hiddenSingleLine: "Hidden Single (Line)"
        case .nakedSingle: "Naked Single"
        case .pointing: "Pointing"
        case .claiming: "Claiming"
        case .lockedPair: "Locked Pair"
        case .lockedTriple: "Locked Triple"
        case .nakedPair: "Naked Pair"
        case .hiddenPair: "Hidden Pair"
        case .nakedTriple: "Naked Triple"
        case .hiddenTriple: "Hidden Triple"
        case .nakedQuad: "Naked Quad"
        case .hiddenQuad: "Hidden Quad"
        case .xWing: "X-Wing"
        case .swordfish: "Swordfish"
        case .jellyfish: "Jellyfish"
        case .finnedXWing: "Finned X-Wing"
        case .sashimiXWing: "Sashimi X-Wing"
        case .finnedSwordfish: "Finned Swordfish"
        case .sashimiSwordfish: "Sashimi Swordfish"
        case .finnedJellyfish: "Finned Jellyfish"
        case .sashimiJellyfish: "Sashimi Jellyfish"
        case .skyscraper: "Skyscraper"
        case .twoStringKite: "2-String Kite"
        case .turbotFish: "Turbot Fish"
        case .emptyRectangle: "Empty Rectangle"
        case .xyWing: "XY-Wing"
        case .xyzWing: "XYZ-Wing"
        case .wWing: "W-Wing"
        case .wxyzWing: "WXYZ-Wing"
        case .uniqueRectangle1: "Unique Rectangle Type 1"
        case .uniqueRectangle2: "Unique Rectangle Type 2"
        case .uniqueRectangle3: "Unique Rectangle Type 3"
        case .uniqueRectangle4: "Unique Rectangle Type 4"
        case .uniqueRectangle5: "Unique Rectangle Type 5"
        case .uniqueRectangle6: "Unique Rectangle Type 6"
        case .hiddenRectangle: "Hidden Rectangle"
        case .avoidableRectangle: "Avoidable Rectangle Type 1"
        case .avoidableRectangle2: "Avoidable Rectangle Type 2"
        case .bugPlusOne: "BUG+1"
        case .simpleColoring: "Simple Coloring Trap"
        case .colorWrap: "Simple Coloring Wrap"
        case .multiColoring: "Multi-Coloring"
        case .remotePair: "Remote Pair"
        case .xChain: "X-Chain"
        case .xyChain: "XY-Chain"
        case .niceLoop: "Continuous Nice Loop"
        case .discontinuousNiceLoop: "Discontinuous Nice Loop"
        case .aic: "Alternating Inference Chain"
        case .frankenFish: "Franken Fish"
        case .mutantFish: "Mutant Fish"
        case .krakenFish: "Kraken Fish"
        case .groupedAIC: "Grouped AIC"
        case .sueDeCoq: "Sue de Coq"
        case .alsXZ: "ALS-XZ"
        case .alsXYWing: "ALS-XY-Wing"
        case .alsChain: "ALS Chain"
        case .deathBlossom: "Death Blossom"
        case .cellForcingChain: "Cell Forcing Chain"
        case .unitForcingChain: "Unit Forcing Chain"
        case .forcingContradiction: "Forcing Chain Contradiction"
        case .forcingNet: "Forcing Net"
        case .bruteForce: "Trial and Error"
        }
    }

    /// Relative difficulty used to order the solver and rate puzzles. Our own scale and tiers, with
    /// the relative order following HoDoKu's defaults where the two disagreed: Remote Pair, finned
    /// and sashimi X-Wings, Turbot Fish, the uniqueness family, Jellyfish, Multi-Coloring and singles.
    public var score: Int {
        switch self {
        case .fullHouse: 4
        case .hiddenSingleBox: 8
        case .hiddenSingleLine: 12
        case .nakedSingle: 6
        case .pointing: 30
        case .claiming: 35
        case .lockedPair: 37
        case .nakedPair: 40
        case .lockedTriple: 45
        case .hiddenPair: 50
        case .nakedTriple: 60
        case .hiddenTriple: 70
        case .bugPlusOne: 100
        case .uniqueRectangle1: 100
        case .xWing: 110
        case .skyscraper: 120
        case .twoStringKite: 125
        case .uniqueRectangle2: 101
        case .nakedQuad: 135
        case .hiddenQuad: 140
        case .uniqueRectangle4: 102
        case .xyWing: 150
        case .emptyRectangle: 155
        case .turbotFish: 118
        case .swordfish: 165
        case .xyzWing: 170
        case .wWing: 175
        case .uniqueRectangle3: 105
        case .hiddenRectangle: 106
        case .avoidableRectangle: 107
        case .avoidableRectangle2: 108
        case .uniqueRectangle5: 103
        case .uniqueRectangle6: 104
        case .simpleColoring: 190
        case .colorWrap: 192
        case .finnedXWing: 109
        case .sashimiXWing: 128
        case .remotePair: 105
        case .jellyfish: 168
        case .finnedSwordfish: 230
        case .sashimiSwordfish: 235
        case .multiColoring: 196
        case .xChain: 250
        case .wxyzWing: 255
        case .finnedJellyfish: 260
        case .sashimiJellyfish: 265
        case .xyChain: 270
        case .niceLoop: 285
        case .discontinuousNiceLoop: 300
        case .aic: 300
        case .frankenFish: 340
        case .mutantFish: 420
        case .krakenFish: 450
        case .sueDeCoq: 310
        case .alsXZ: 320
        case .groupedAIC: 330
        case .alsXYWing: 360
        case .alsChain: 380
        case .deathBlossom: 400
        case .cellForcingChain: 500
        case .unitForcingChain: 520
        case .forcingContradiction: 550
        case .forcingNet: 600
        case .bruteForce: 1000
        }
    }

    public var difficulty: Difficulty {
        switch score {
        case ..<20: .beginner
        case ..<100: .easy
        case ..<150: .medium
        case ..<200: .hard
        case ..<300: .expert
        case ..<500: .master
        default: .extreme
        }
    }

    /// Whether the technique relies on the puzzle having a unique solution.
    public var assumesUniqueness: Bool {
        switch self {
        case .uniqueRectangle1, .uniqueRectangle2, .uniqueRectangle3, .uniqueRectangle4, .uniqueRectangle5, .uniqueRectangle6,
             .hiddenRectangle, .avoidableRectangle, .avoidableRectangle2, .bugPlusOne: true
        default: false
        }
    }

    /// One-sentence teaching summary of the idea behind the technique.
    public var summary: String {
        switch self {
        case .fullHouse: "A house with only one empty cell: it gets the one missing digit."
        case .hiddenSingleBox: "A digit that has only one possible cell left in a box."
        case .hiddenSingleLine: "A digit that has only one possible cell left in a row or column."
        case .nakedSingle: "A cell with only one candidate left."
        case .pointing: "When a digit's candidates in a box all lie on one line, the digit can be removed from the rest of that line."
        case .claiming: "When a digit's candidates in a line all lie in one box, the digit can be removed from the rest of that box."
        case .lockedPair: "A naked pair that sits in both a line and a box, so both digits can go from the rest of both houses."
        case .lockedTriple: "A naked triple inside one box/line intersection: its digits leave the rest of the box and the line."
        case .nakedPair: "Two cells in a house holding the same two candidates; those digits can go nowhere else in the house."
        case .hiddenPair: "Two digits that only fit in the same two cells of a house; other candidates in those cells can go."
        case .nakedTriple: "Three cells in a house limited to the same three digits."
        case .hiddenTriple: "Three digits confined to the same three cells of a house."
        case .nakedQuad: "Four cells in a house limited to the same four digits."
        case .hiddenQuad: "Four digits confined to the same four cells of a house."
        case .xWing: "A digit confined to the same two columns in two rows (or vice versa) can be removed from the rest of those columns."
        case .swordfish: "An X-Wing with three rows and three columns."
        case .jellyfish: "An X-Wing with four rows and four columns."
        case .finnedXWing, .finnedSwordfish, .finnedJellyfish: "A fish with a few extra candidates (fins) in one box; eliminations must also see the fins."
        case .sashimiXWing, .sashimiSwordfish, .sashimiJellyfish: "A finned fish where one base line is missing a corner and relies on the fin."
        case .skyscraper: "Two parallel strong links on one digit that share one end line; anything seeing both free ends is eliminated."
        case .twoStringKite: "A row strong link and a column strong link on one digit joined through a box."
        case .turbotFish: "Strong link - weak link - strong link on a single digit."
        case .emptyRectangle: "A box where a digit is confined to one row and one column, combined with a strong link outside the box."
        case .xyWing: "A bivalue pivot XY sees XZ and YZ cells; Z is removed from cells seeing both wings."
        case .xyzWing: "Like an XY-Wing but the pivot also holds Z, so targets must see the pivot too."
        case .wWing: "Two identical bivalue cells joined by a strong link on one of their digits."
        case .wxyzWing: "Four cells holding four digits where only one digit is not mutually visible."
        case .uniqueRectangle1: "Avoid the deadly pattern: three corners of a rectangle are the same pair, so the fourth can't be either."
        case .uniqueRectangle2: "Two rectangle corners share one extra candidate; one of them must be it."
        case .uniqueRectangle3: "The rectangle's extra candidates act as one cell in a naked subset."
        case .uniqueRectangle4: "One rectangle digit is locked to the roof cells, so the other digit can go from both."
        case .uniqueRectangle5: "Several rectangle corners share one extra candidate; one of them must hold it."
        case .uniqueRectangle6: "A rectangle digit forms an X-Wing on the rectangle, so it must sit on the bivalue diagonal."
        case .avoidableRectangle2: "Two solved (non-given) corners and two open corners would form a swappable rectangle unless an open corner takes its extra digit."
        case .avoidableRectangle: "Three solved (non-given) corners would let the fourth complete a swappable rectangle."
        case .hiddenRectangle: "Strong links around a rectangle force one corner to avoid the deadly pattern."
        case .bugPlusOne: "Every cell but one is bivalue; the extra candidate in that cell must be true."
        case .simpleColoring: "Color a digit's strong-link chain in two colors; one color is true, so a cell seeing both colors loses the digit."
        case .colorWrap: "Color a digit's strong-link chain in two colors; if two cells of one color see each other, that whole color is false."
        case .multiColoring: "Two colored clusters on one digit interact to eliminate more."
        case .remotePair: "A chain of identical bivalue cells; cells seeing both ends of opposite parity lose both digits."
        case .xChain: "An alternating chain of strong and weak links on one digit."
        case .xyChain: "A chain through bivalue cells; the end digit is eliminated from cells seeing both ends."
        case .discontinuousNiceLoop: "A chain that starts and ends in the same cell: the cell either keeps only the chain's digits or must take one of them."
        case .niceLoop: "A chain that closes on itself: every weak link in the loop becomes strong."
        case .frankenFish: "A fish whose base or cover sets include boxes."
        case .mutantFish: "A fish mixing rows, columns and boxes freely in its base and cover sets."
        case .krakenFish: "A fish with fins where every fin, if true, still eliminates the target."
        case .aic: "An alternating chain of strong and weak inferences mixing digits and cells."
        case .groupedAIC: "An alternating chain that uses groups of cells as links."
        case .sueDeCoq: "A box/line intersection paired with cells in the box and line forms two locked sets."
        case .alsXZ: "Two almost locked sets linked by a restricted common digit."
        case .alsXYWing: "Three almost locked sets in an XY-Wing shape."
        case .alsChain: "A chain of almost locked sets joined by restricted common digits."
        case .deathBlossom: "A stem cell whose every candidate locks an almost locked set petal."
        case .cellForcingChain: "Every candidate of one cell leads, by a simple chain, to the same conclusion."
        case .unitForcingChain: "Every position of a digit in a house leads, by a simple chain, to the same conclusion."
        case .forcingContradiction: "Assuming a candidate (or its absence) leads by simple chains to a contradiction, so the opposite is true."
        case .forcingNet: "Like a forcing chain, but some steps need several earlier conclusions at once (a cell or house left with one option)."
        case .bruteForce: "No known technique applies; a value is revealed from the solution."
        }
    }
}
