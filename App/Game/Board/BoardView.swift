import SwiftUI
import SudokuCore

struct BoardView: View {
    let game: Game
    @AppStorage("mistakeMode") private var mistakeMode: MistakeMode = .conflicts
    @AppStorage("highlightSame") private var highlightSame = true
    @AppStorage("highlightPeers") private var highlightPeers = true

    var body: some View {
        let ctx = BoardContext(game: game, mistakeMode: mistakeMode, highlightSame: highlightSame, highlightPeers: highlightPeers)
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let cell = side / 9
            ZStack(alignment: .topLeading) {
                VStack(spacing: 0) {
                    ForEach(0..<9, id: \.self) { r in
                        HStack(spacing: 0) {
                            ForEach(0..<9, id: \.self) { col in
                                CellView(game: game, cell: r * 9 + col, ctx: ctx, size: cell)
                                    .frame(width: cell, height: cell)
                            }
                        }
                    }
                }
                GridLines()
                    .stroke(Color.primary.opacity(0.25), lineWidth: 0.5)
                GridLines(boxesOnly: true)
                    .stroke(Color.primary.opacity(0.85), lineWidth: 2)
            }
            .frame(width: side, height: side)
            // One tap handler for the whole board, mapped from the tap location to a cell.
            .contentShape(Rectangle())
            .onTapGesture(coordinateSpace: .local) { p in
                let r = min(8, max(0, Int(p.y / cell))), col = min(8, max(0, Int(p.x / cell)))
                game.tapCell(r * 9 + col)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Sudoku board")
    }
}
