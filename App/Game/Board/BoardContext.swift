import SwiftUI
import SudokuCore

/// Everything a cell needs to draw itself, computed once per board render.
struct BoardContext {
    var selected: Int?
    /// Two or more selected cells (see `Game.multiSelection`).
    var multiSelection = CellSet()
    /// Digit to emphasize: the armed digit, else the selected cell's value.
    var highlightDigit: Int
    var peers: CellSet
    var conflicts: Set<Int>
    var mistakeMode: MistakeMode
    var highlightSame: Bool
    var highlightPeers: Bool
    // Hint overlay
    var hintHouses: CellSet = CellSet()
    var hintRoles: [Int: [Int: Highlight.Role]] = [:]   // cell -> digit (0 = cell) -> role
    var hintElims: Set<Candidate> = []
    var hintPlacements: Set<Candidate> = []
    var hintWrong: Set<Int> = []
    var hintMissing: Set<Candidate> = []
    /// A hint is drawing on the board. Its colors then stand alone: the selection, peer and
    /// same-digit tints are suppressed so the two kinds of highlighting don't mix.
    var hintOnBoard: Bool {
        !hintHouses.isEmpty || !hintRoles.isEmpty || !hintWrong.isEmpty || !hintMissing.isEmpty
    }

    func isSelected(_ c: Int) -> Bool { multiSelection.isEmpty ? selected == c : multiSelection.contains(c) }

    @MainActor
    init(game: Game, mistakeMode: MistakeMode, highlightSame: Bool, highlightPeers: Bool) {
        selected = game.selected
        multiSelection = game.multiSelection
        // With several cells selected, no one cell's digit or peers stands out.
        let single = multiSelection.isEmpty ? game.selected : nil
        highlightDigit = game.armed?.digit ?? single.map { game.value($0) } ?? game.lastDigit ?? 0
        peers = single.map { Geometry.peerSets[$0] } ?? CellSet()
        conflicts = mistakeMode == .off ? [] : game.conflicts
        self.mistakeMode = mistakeMode
        self.highlightSame = highlightSame
        self.highlightPeers = highlightPeers

        guard let h = game.hint else { return }
        switch h.hint {
        case .solved: break
        case .wrongValues(let cells):
            hintWrong = Set(cells)
        case .missingCandidates(let cs):
            hintMissing = Set(cs)
        case .step(let s):
            if h.level >= .region {
                let hs = s.houses.isEmpty ? Geometry.sharedHouses(s.patternCells.array) : s.houses
                for house in hs { hintHouses |= Geometry.houseSets[house] }
                if hs.isEmpty { hintHouses = s.patternCells }
            }
            if h.level >= .pattern {
                for hl in s.highlights { hintRoles[hl.cell, default: [:]][hl.digit] = hl.role }
            }
            if h.level >= .answer {
                hintElims = Set(s.eliminations)
                hintPlacements = Set(s.placements)
            }
        }
        if hintOnBoard {
            self.highlightSame = false
            self.highlightPeers = false
        }
    }
}
