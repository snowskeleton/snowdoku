import SwiftUI
import SudokuCore

struct ControlsView: View {
    @Bindable var game: Game

    var body: some View {
        HStack {
            Button("Undo", systemImage: "arrow.uturn.backward", action: game.undo)
                .disabled(!game.canUndo)
            Button("Erase", systemImage: "eraser", action: game.erase)
            Button("Fill", systemImage: "square.grid.3x3.middle.filled", action: game.fillNotes)
            Button("Hint", systemImage: "lightbulb", action: showHint)
        }
        .labelStyle(VerticalLabelStyle())
        .buttonStyle(ControlButtonStyle())
        .disabled(game.isComplete)
    }

    func showHint() {
        withAnimation { game.requestHint() }
    }
}
