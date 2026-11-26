import SudokuCore

extension Technique {
    /// The long-form explanation on a technique's page: what the pattern is, why it works and
    /// how to spot it. Paragraphs, with inline Markdown. A real example from the drill bank is
    /// shown underneath, so the text can stay general.
    var guide: [String] {
        switch self {
        // MARK: Singles
        case .fullHouse:
            [
                "Every row, column and box holds each digit exactly once. When a house has eight digits filled in, the last empty cell must take the one digit that's missing.",
                "**How to spot it:** look for a row, column or box with a single gap. Count which digit from 1 to 9 isn't there yet.",
            ]
        case .hiddenSingleBox:
            [
                "Pick a digit and a box that doesn't have it yet. Every copy of that digit already on the board rules out its whole row and column. If those lines cover every empty cell in the box except one, the digit has to go there, even if the cell could hold other digits too.",
                "It's called **hidden** because the cell itself may look wide open. What's special is that it's the only home for that digit in the box.",
                "**How to spot it:** take one digit at a time and sweep across the boxes, crossing out the rows and columns where it already appears. Digits that are already placed many times are the quickest wins.",
            ]
        case .hiddenSingleLine:
            [
                "The same idea as a hidden single in a box, applied to a row or column: a digit that the row needs can only go in one of its cells, because every other empty cell already sees that digit in its column or box.",
                "Lines are harder to scan than boxes because the cells that rule each other out are spread across three boxes.",
                "**How to spot it:** choose a row or column that's nearly full, list the digits it's missing, and for each one check which empty cells it can still reach.",
            ]
        case .nakedSingle:
            [
                "Look at one cell instead of one digit. Its row, column and box together already contain eight different digits, so only one digit is left that the cell can hold.",
                "With notes filled in, a naked single is a cell with a single note. Without notes, you find one by counting the distinct digits a cell can see.",
                "**How to spot it:** cells at the crossing of a crowded row, a crowded column and a crowded box are the best candidates.",
            ]

        // MARK: Intersections
        case .pointing:
            [
                "Inside a box, suppose every cell where a digit can still go lies on the same row (or column). The box needs that digit somewhere, so it will end up on that line, inside this box.",
                "That means the rest of the line, outside the box, can't have the digit: the line's copy is already accounted for. Remove it from those cells.",
                "**How to spot it:** in a box, look for a digit whose notes sit in two or three cells that line up. Then follow that line out of the box.",
            ]
        case .claiming:
            [
                "The mirror image of pointing. Suppose that in a row (or column), every cell where a digit can still go lies inside a single box. The line needs that digit, so it'll be placed in that box, on this line.",
                "The box then already has its copy of the digit, so the digit can be removed from the box's other cells, the ones off the line.",
                "**How to spot it:** for a row or column, check whether a digit's notes are all bunched into one of its three box segments.",
            ]

        // MARK: Subsets
        case .nakedPair:
            [
                "Two cells in the same house that both have exactly the same two candidates, say 3 and 7. One of them will be 3 and the other 7; we just don't know which yet.",
                "Either way, 3 and 7 are used up in that house, so remove them from every other cell of the house. If the two cells share a box *and* a line, you can clear both houses.",
                "**How to spot it:** look for matching two-note cells in the same row, column or box.",
            ]
        case .hiddenPair:
            [
                "Two digits that, within a house, can each go only into the same two cells. Those two cells must hold those two digits, so any other candidates in them can be removed.",
                "It's the hidden counterpart of a naked pair. The two cells often have several notes each, which is what hides the pair.",
                "**How to spot it:** in a house, count where each missing digit can go. Two digits that both have exactly the same two spots form the pair.",
            ]
        case .nakedTriple:
            [
                "Three cells in a house whose candidates, taken together, are just three digits. Not every cell needs all three: {1,2}, {2,3} and {1,3} is a naked triple too.",
                "Three cells with only three digits between them must use all three, so those digits can be removed from the rest of the house.",
                "**How to spot it:** look for cells with two or three notes drawn from the same small set of digits.",
            ]
        case .hiddenTriple:
            [
                "Three digits that, within a house, are confined to the same three cells (each digit appears in two or three of them). Those cells must hold those digits, so every other candidate in them can go.",
                "**How to spot it:** in a house, list where each missing digit can go. If three digits only ever appear in the same three cells, you have it.",
            ]
        case .nakedQuad:
            [
                "Four cells in a house whose candidates together are only four digits. They'll take those four digits between them, so remove the four from the other cells of the house.",
                "Quads are rare and easy to miss, because the cells usually have a mix of two-, three- and four-note cells. When a house has eight empty cells, a naked quad and a hidden quad come as a pair: spot whichever is smaller.",
            ]
        case .hiddenQuad:
            [
                "Four digits confined to the same four cells of a house. Those cells must hold those four digits, so their other candidates can be removed.",
                "When a house has many empty cells and one group of digits keeps to the same corner of it, check for a hidden quad. It's often easier to find the matching naked subset in the remaining cells.",
            ]

        // MARK: Fish
        case .xWing:
            [
                "Pick a digit. Suppose that in two different rows it can go in only two cells each, and those cells are in the same two columns. The four cells form a rectangle.",
                "In the first row the digit goes in one column or the other; the second row must then use the other column. Either way, the digit occupies both columns within those two rows.",
                "So the digit can be removed from every other cell of those two columns. The same works with columns and rows swapped.",
                "**How to spot it:** for one digit, find rows where it has exactly two spots, and look for two such rows whose spots line up.",
            ]
        case .swordfish:
            [
                "An X-Wing grown to three lines. For one digit, three rows each have its candidates in only two or three cells, and all of them fall within the same three columns.",
                "The three rows need three copies of the digit, and they can only put them in those three columns, one per column. That uses up the digit in those columns, so remove it from the columns' other cells.",
                "**How to spot it:** filter the board to one digit and look for three rows whose candidates span just three columns. A row doesn't have to touch all three.",
            ]
        case .jellyfish:
            [
                "The four-line version of an X-Wing and Swordfish. For one digit, four rows keep their candidates inside the same four columns, so those four columns are filled with the digit by these rows, and its other candidates in those columns can go.",
                "Jellyfish are rare; a smaller fish or a chain usually shows up first.",
            ]
        case .finnedXWing, .finnedSwordfish, .finnedJellyfish:
            [
                "A fish that's almost there: the pattern would be a perfect \(fishName) except for one or two extra candidates, the **fin**, all in one box.",
                "Either the fin is true or it isn't. If it isn't, the fish is perfect and makes its usual eliminations. If it is, the fin's cell holds the digit. So a cell is safe to clear only if both cases rule it out: it must be one of the fish's eliminations *and* see the fin, which in practice means it's in the fin's box.",
                "**How to spot it:** look for an almost-\(fishName) for one digit where the stray candidates sit in one box next to a corner of the pattern.",
            ]
        case .sashimiXWing, .sashimiSwordfish, .sashimiJellyfish:
            [
                "A finned \(fishName) where one corner of the pattern is missing entirely. The fin in that corner's box stands in for it.",
                "The logic is the same as for a finned fish: either the fin is false and the (degenerate) \(fishName) holds, or the fin is true. Only cells that are eliminated by the fish *and* see every fin cell can be cleared.",
                "**How to spot it:** a line with the digit in just one cell of the pattern, plus one or two cells in the same box but in a different line.",
            ]

        // MARK: Single-digit patterns
        case .skyscraper:
            [
                "A **strong link** on a digit is a house where it has exactly two spots: one of them must be it. A skyscraper uses two such links on the same digit in two parallel lines, say two columns, whose bottom ends share a row.",
                "The shared row can hold the digit only once, so at most one of the two bottom ends is true. That means at least one of the two top ends is.",
                "Any cell that sees both top ends would clash with whichever one is true, so the digit can be removed from it.",
                "**How to spot it:** for one digit, find two columns (or rows) with exactly two candidates each, aligned at one end and offset at the other.",
            ]
        case .twoStringKite:
            [
                "Two strong links on one digit, one in a row and one in a column, with one end of each in the same box. The two ends inside the box can't both be true, so at least one of the two far ends is.",
                "A cell that sees both far ends (usually the cell at the crossing of the row of one and the column of the other) can't hold the digit.",
                "**How to spot it:** for one digit, pick a box where it has a few candidates and look for a row and a column leaving that box that each have exactly two spots.",
            ]
        case .turbotFish:
            [
                "The general shape behind skyscrapers and kites: a strong link, then a weak link (two cells that see each other), then another strong link, all on one digit.",
                "Walk along it: if the first end is false, the second cell is true, so the third is false, so the fourth is true. Either the first end or the last end holds the digit, so cells seeing both ends lose it.",
                "Most turbot fish are skyscrapers or kites and get those names; the rest join strong links through a box in other ways.",
            ]
        case .emptyRectangle:
            [
                "Look at one digit inside a box. If its candidates there all lie on one row and one column of the box (a plus or an L shape, with the other corner cells empty), then the box's copy is on that row or that column.",
                "Combine it with a strong link outside: a line where the digit has exactly two spots, one of which lines up with the box's row or column. Following the link shows a cell outside the box that would leave the box with nowhere to put the digit, so the digit is removed from that cell.",
                "**How to spot it:** find a box where one digit forms a cross, then look for a two-candidate line that points into it.",
            ]

        // MARK: Wings
        case .xyWing:
            [
                "Three cells with two candidates each. The **pivot** has XY. One **pincer** that sees the pivot has XZ; another pincer that sees it has YZ.",
                "If the pivot is X, the XZ pincer must be Z. If the pivot is Y, the YZ pincer must be Z. Either way one of the pincers is Z.",
                "So any cell that sees both pincers can't be Z.",
                "**How to spot it:** find a two-note cell, then look among the cells it sees for two others that each share one of its digits and have the same third digit.",
            ]
        case .xyzWing:
            [
                "Like an XY-Wing, but the pivot holds all three digits, XYZ, with pincers XZ and YZ.",
                "Now there's a third case: the pivot itself could be Z. Whatever happens, one of the three cells is Z, so only cells that see all three of them, the pivot and both pincers, can lose Z. These are usually in the pivot's box.",
            ]
        case .wWing:
            [
                "Two cells, not seeing each other, that both have exactly the same two candidates, say X and Y. Somewhere else, a strong link on X connects a cell seeing the first to a cell seeing the second.",
                "One end of that link is X. Whichever end it is, the bivalue cell it sees can't be X, so that cell is Y. So at least one of the two bivalue cells is Y, and any cell seeing both can't be Y.",
                "**How to spot it:** find a matching pair of two-note cells that don't share a house, then look for a two-spot line or box on one of their digits between them.",
            ]
        case .wxyzWing:
            [
                "An XY-Wing stretched over four cells and four digits. Among the cells, every digit except one (Z) only appears in cells that all see each other, so those digits can't clash.",
                "That makes the four cells hold four different digits, and the only way to fit them is for one of the cells with Z to be Z. Cells that see every Z in the pattern can't be Z.",
                "It's hard to spot by eye; look for a cluster of cells around one box with four digits between them.",
            ]

        // MARK: Uniqueness
        case .uniqueRectangle1:
            [
                "Uniqueness techniques assume the puzzle has exactly one solution, which every proper puzzle does.",
                "Picture four cells on two rows, two columns and exactly two boxes, all with candidates {X, Y}. Whatever solution you found, swapping X and Y in those four cells would give a second one. That **deadly pattern** can't happen in a puzzle with one solution.",
                "So when three corners are just {X, Y} and the fourth has extra candidates, the fourth corner must be one of its extras. Remove X and Y from it.",
                "**How to spot it:** look for three matching two-note cells at three corners of a rectangle spanning two boxes.",
            ]
        case .uniqueRectangle2:
            [
                "A unique rectangle where two corners are plain {X, Y} and the other two, the **roof**, are {X, Y, Z} with the same single extra digit Z.",
                "If neither roof cell were Z, the deadly pattern would appear. So one of the roof cells is Z, and any cell that sees both roof cells can't be Z.",
            ]
        case .uniqueRectangle3:
            [
                "A unique rectangle whose two roof cells have extra candidates. To avoid the deadly pattern, at least one roof cell must take one of its extras.",
                "So the roof's extra digits act together like a single cell. Combine that virtual cell with other cells in a shared house to form a naked subset, and the subset's digits can be removed from the rest of the house.",
            ]
        case .uniqueRectangle4:
            [
                "A unique rectangle whose two roof cells have extra candidates. Suppose one rectangle digit, X, can only go in the two roof cells within a house they share.",
                "Then one of the roof cells is X. If the other were Y, the deadly pattern would form, so neither roof cell can be Y. Remove Y from both.",
            ]
        case .uniqueRectangle5:
            [
                "A unique rectangle where two or three corners carry the same single extra digit Z, and the rest are plain {X, Y}.",
                "One of the corners with Z must be Z, or the deadly pattern forms. Any cell that sees every one of them can't be Z.",
            ]
        case .uniqueRectangle6:
            [
                "A unique rectangle with two plain {X, Y} corners diagonally opposite, and the digit X limited to the rectangle's corners in both of its rows (an X-Wing on the rectangle).",
                "X must then sit on one diagonal or the other. If it sat on the two cells with extra candidates, the plain corners would both be Y and the deadly pattern would form. So X goes on the plain diagonal, and X can be removed from the other two corners.",
            ]
        case .hiddenRectangle:
            [
                "A deadly-pattern argument that leans on strong links instead of bare cells. One corner of the rectangle is plain {X, Y}, and the corner opposite it has a strong link on X along both of its lines (X can only go in the rectangle's cells there).",
                "If that opposite corner held Y, those strong links would force X into both of its neighbors and Y into the rest, building the deadly pattern. So the opposite corner can't be Y.",
            ]
        case .avoidableRectangle:
            [
                "A deadly pattern made of cells you solved, not givens. If three corners of a rectangle on two boxes are solved as X, Y, X (none of them given), the fourth corner can't be Y.",
                "If it were, the four solved cells could swap X and Y without breaking any given, so the puzzle would have two solutions.",
            ]
        case .bugPlusOne:
            [
                "BUG stands for Bivalue Universal Grave. If every unsolved cell had exactly two candidates, and every digit appeared exactly twice in each house, the remaining cells could be completed in two ways: a puzzle with one solution can't reach that state.",
                "So when every unsolved cell is bivalue except one cell with three candidates, that cell is what keeps the grave away. Its odd digit, the one that appears three times in its houses, must be its value.",
                "**How to spot it:** late in a hard puzzle, when nearly every cell shows two notes and one shows three.",
            ]

        // MARK: Coloring
        case .simpleColoring:
            [
                "Pick a digit and follow its strong links (houses where it has exactly two spots). Give the cells alternating colors: if one cell is blue, the other end of its link is green, and so on through the chain.",
                "In the solution, either every blue cell holds the digit or every green cell does. Two rules follow. If two cells of the same color see each other, that color is false everywhere. And any uncolored cell that sees both a blue and a green cell can't hold the digit.",
            ]
        case .multiColoring:
            [
                "Color two separate chains of strong links on the same digit, each with its own pair of colors (say blue/green and orange/purple).",
                "If a blue cell sees an orange cell, they can't both be true, so either green or purple holds the digit. Cells that see both a green and a purple cell lose it. And if one color sees both colors of the other chain, that color is false.",
            ]

        // MARK: Chains
        case .remotePair:
            [
                "A chain of cells that all have the same two candidates, X and Y, each seeing the next. Along the chain the values must alternate: X, Y, X, Y...",
                "Two cells an odd number of steps apart hold opposite values, so between them they use both X and Y. A cell that sees both of them can hold neither.",
            ]
        case .xChain:
            [
                "A longer turbot fish: a chain on one digit that alternates **strong links** (a house where the digit has exactly two spots, so one of them is true) and **weak links** (two cells that see each other, so at most one is true), starting and ending with strong links.",
                "Walking the chain shows that if the first end is false, the last end is true. So one of the two ends holds the digit, and any cell seeing both ends can't.",
            ]
        case .xyChain:
            [
                "A chain through two-note cells, each seeing the next, where neighbors share a digit. It starts and ends with the same digit Z.",
                "If the first cell isn't Z, it's its other digit, which forces the next cell to its other digit, and so on, until the last cell is Z. So one end is Z, and any cell seeing both ends can't be Z. An XY-Wing is the shortest XY-Chain.",
            ]
        case .niceLoop:
            [
                "An alternating chain that closes back on its starting point with the alternation intact. Then the chain must work in both directions, so every weak link in the loop is actually strong: of the two candidates it joins, exactly one is true.",
                "That gives eliminations along every weak link: other candidates in the same cell (for a link inside a cell), or other cells of the house that see both ends (for a link along a house).",
            ]
        case .aic:
            [
                "Alternating Inference Chains generalize X- and XY-Chains: links can be on one digit between cells, or between two digits in one cell. They still alternate strong (at least one is true) and weak (at most one is true).",
                "Starting and ending with strong links means one of the two end candidates is true. If both ends are the same digit, cells seeing both lose it. If they're different digits in the same cell, that cell's other candidates go.",
            ]
        case .groupedAIC:
            [
                "An AIC where some nodes are groups: two or three cells of a box that lie on one line and share a digit. A group counts as true if the digit is in any of its cells.",
                "Groups let the chain use pointing-style links, which reach places single-cell chains can't.",
            ]

        // MARK: Exotic fish
        case .frankenFish:
            [
                "A fish whose base or cover lines include boxes. For one digit, the base houses (where every candidate must be covered) and cover houses (where the eliminations happen) mix rows or columns with boxes.",
                "The logic is the same as an X-Wing: the base houses need as many copies of the digit as there are houses, and they can only place them within the cover houses, filling them up.",
            ]
        case .mutantFish:
            [
                "The most general fish: base and cover sets mix rows, columns and boxes in any combination. Every base candidate lies in some cover house, and there are as many cover houses as base houses, so the cover houses' other candidates can go.",
            ]
        case .krakenFish:
            [
                "A finned fish whose fins aren't in one box. For each fin, follow a chain from \"this fin is true\" and show it also eliminates the target.",
                "Either no fin is true and the plain fish eliminates the target, or some fin is true and its chain does. Both ways, the target goes.",
            ]

        // MARK: Almost locked sets
        case .sueDeCoq:
            [
                "Take two or three cells where a box and a line cross. Together they hold some digits; split those digits between a set in the rest of the line and a set in the rest of the box.",
                "When the counts line up, the intersection, the line cells and the box cells form two locked sets. The line set's digits can be removed from the rest of the line, and the box set's from the rest of the box.",
            ]
        case .alsXZ:
            [
                "An **almost locked set** (ALS) is N cells in one house holding N+1 digits: remove any one digit and the rest are locked.",
                "Two ALSs share a **restricted common** digit X when every X in one sees every X in the other, so only one of them can hold X. Then one of the sets is locked without X. If both sets also hold a digit Z, one of them must place a Z, so cells seeing every Z in both sets can't be Z.",
            ]
        case .alsXYWing:
            [
                "An XY-Wing made of almost locked sets. A pivot ALS shares restricted commons X with one wing ALS and Y with another; both wings contain Z.",
                "Like a regular XY-Wing, at least one wing ends up holding Z, so cells seeing every Z in both wings lose it.",
            ]
        case .alsChain:
            [
                "A chain of almost locked sets, each joined to the next by a restricted common digit. The chain carries the logic from one end to the other.",
                "If the two end sets share a digit Z (not used as a link at the ends), one of them holds Z, so cells seeing all those Zs can't.",
            ]
        case .deathBlossom:
            [
                "A **stem** cell with several candidates, and one almost locked set (a **petal**) for each of them. Each petal contains that candidate where it sees the stem, plus a common digit Z.",
                "Whatever the stem turns out to be, the matching petal loses that digit and locks, placing a Z. So cells seeing every Z in every petal can't be Z.",
            ]

        // MARK: Forcing
        case .cellForcingChain:
            [
                "Pick a cell and try each of its candidates in turn, following the forced consequences with chains.",
                "If every candidate leads to the same result (the same digit placed somewhere, or the same candidate removed), that result is true no matter what the cell is.",
            ]
        case .unitForcingChain:
            [
                "Like a cell forcing chain, but starting from a house: try each cell where a digit can go in that house. The digit has to be in one of them.",
                "If every option leads to the same conclusion, the conclusion holds.",
            ]
        case .forcingContradiction:
            [
                "Assume a candidate is true and follow the forced consequences. If they lead to an impossibility, such as a cell with no candidates left or a digit with nowhere to go in a house, the assumption was wrong. Remove the candidate.",
                "This is reasoning by contradiction. It's a step up from guessing because you follow the logic to the end before deciding.",
            ]
        case .forcingNet:
            [
                "A forcing chain that's allowed to branch and to use simple techniques (locked candidates, naked pairs) along the way, not just single forced moves.",
                "It's the last logical resort before trial and error, and almost every puzzle that resists everything else gives way to it.",
            ]

        case .bruteForce:
            ["No technique the engine knows applies, so a cell is revealed from the solution."]
        }
    }

    /// "X-Wing", "Swordfish" or "Jellyfish": the basic fish under a finned or sashimi one.
    private var fishName: String {
        switch self {
        case .finnedXWing, .sashimiXWing: "X-Wing"
        case .finnedSwordfish, .sashimiSwordfish: "Swordfish"
        default: "Jellyfish"
        }
    }
}
