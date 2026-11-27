import SwiftUI
import SudokuCore

struct HintPanel: View {
    @Bindable var game: Game
    /// The technique page opened from the hint, in a sheet over the game.
    @State private var learning: Technique?

    var body: some View {
        if let h = game.hint {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    Image(systemName: "lightbulb.fill").foregroundStyle(.yellow)
                    Text(text(h)).fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    Button("Close hint", systemImage: "xmark", action: close)
                        .labelStyle(.iconOnly)
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                        .padding(-12) // keep the 44pt target without pushing the text down
                }
                HStack {
                    if case .step = h.hint, h.level < .answer {
                        Button("Show more", action: showMore)
                            .buttonStyle(.bordered)
                    }
                    // Once the hint names the technique, link to its page.
                    if case .step(let s) = h.hint, h.level >= .technique, s.technique != .bruteForce {
                        Button { learning = s.technique } label: {
                            Label("Learn", systemImage: "book")
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Learn \(s.technique.name)")
                    }
                    Spacer()
                    if applicable(h) {
                        Button(applyLabel(h), action: apply)
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.regularMaterial)
                    .strokeBorder(Color.primary.opacity(0.08))
            }
            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
            .sheet(item: $learning, onDismiss: game.resumeClock) { t in
                NavigationStack {
                    TechniqueDetailView(technique: t, showsPractice: false)
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { learning = nil }
                            }
                        }
                }
                .onAppear(perform: game.pauseClock)
                #if os(macOS)
                .frame(minWidth: 480, idealWidth: 560, minHeight: 560, idealHeight: 720)
                #endif
            }
        }
    }

    func close() { withAnimation { game.hint = nil } }
    func showMore() { withAnimation { game.requestHint() } }
    func apply() { withAnimation { game.applyHint() } }

    func text(_ h: HintSession) -> String {
        switch h.hint {
        case .solved: return "The puzzle is solved!"
        case .wrongValues(let cells):
            return cells.count == 1 ? "\(Geometry.cellName(cells[0])) has the wrong value." : "\(cells.count) cells have wrong values."
        case .missingCandidates(let cs):
            return "Some of your notes removed the real answer: \(cs.prefix(4).map(\.description).formatted())\(cs.count > 4 ? "…" : "")."
        case .step(let s):
            return s.hintText(h.level)
        }
    }

    func applicable(_ h: HintSession) -> Bool {
        switch h.hint {
        case .solved: false
        case .step: h.level == .answer
        default: true
        }
    }

    func applyLabel(_ h: HintSession) -> String {
        switch h.hint {
        case .wrongValues: "Clear them"
        case .missingCandidates: "Restore notes"
        default: "Apply"
        }
    }
}
