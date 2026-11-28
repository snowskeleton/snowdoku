import SwiftUI
import SudokuCore

struct SettingsView: View {
    @AppStorage("mistakeMode") private var mistakeMode: MistakeMode = .conflicts
    @AppStorage("autoRemoveNotes") private var autoRemoveNotes = true
    @AppStorage("highlightSame") private var highlightSame = true
    @AppStorage("highlightPeers") private var highlightPeers = true
    @AppStorage("showTimer") private var showTimer = true
    @AppStorage("autoComplete") private var autoComplete = true
    @AppStorage("autoCompleteThreshold") private var autoCompleteThreshold = 15
    @AppStorage("padLayout") private var padLayout: PadLayout = .twoPads
    @AppStorage("noteNotation") private var noteNotation: NoteNotation = .manual
    @AppStorage("shiftClickNotes") private var shiftClickNotes = true
    @AppStorage("rightClickRemovesNote") private var rightClickRemovesNote = true
    @State private var showWhatsNew = false

    var body: some View {
        Form {
            Section("Mistakes") {
                Picker("Show mistakes", selection: $mistakeMode) {
                    ForEach(MistakeMode.allCases) { Text($0.label).tag($0) }
                }
            }
            Section {
                Picker("Layout", selection: $padLayout) {
                    ForEach(PadLayout.allCases) { Text($0.label).tag($0) }
                }
                Picker("Note style", selection: $noteNotation) {
                    ForEach(NoteNotation.allCases) { Text($0.label).tag($0) }
                }
            } header: {
                Text("Number pad")
            } footer: {
                Text((padLayout == .twoPads
                      ? "One pad enters values, the other enters notes."
                      : "Keys beside the pad choose what it enters: digits, notes in the cell's 3×3 grid, or notes centered in the cell.")
                     + " Note style sets how the notes pad, Shift and Fill draw notes: Manual uses the 3×3 grid; Auto centers up to three notes and uses the grid from four.")
            }
            Section("Assistance") {
                Toggle("Remove notes when placing a digit", isOn: $autoRemoveNotes)
                Toggle("Highlight matching digits", isOn: $highlightSame)
                Toggle("Highlight row, column and box", isOn: $highlightPeers)
            }
            Section {
                Toggle("Offer to finish obvious endgames", isOn: $autoComplete)
                if autoComplete {
                    Stepper("When \(autoCompleteThreshold) or fewer cells remain", value: $autoCompleteThreshold, in: 5...40, step: 5)
                }
            } header: {
                Text("Auto-complete")
            } footer: {
                Text("Shows a Finish button when only singles are left and nothing is wrong. Not offered on Beginner puzzles.")
            }
            if showsPointerSettings {
                Section {
                    Toggle("Shift-click enters a note", isOn: $shiftClickNotes)
                    Toggle("Right-click removes a note", isOn: $rightClickRemovesNote)
                } header: {
                    Text("Mouse and trackpad")
                } footer: {
                    Text("With a digit chosen on either pad, Shift-click puts it in a cell as a note, and right-click takes that note out.")
                }
            }
            Section("Display") {
                Toggle("Show timer", isOn: $showTimer)
            }
            Section("About") {
                LabeledContent("Version", value: Changelog.currentVersion)
                Button("What's New") { showWhatsNew = true }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .sheet(isPresented: $showWhatsNew) { WhatsNewView() }
        #if DEBUG
        .task {
            if ProcessInfo.processInfo.arguments.contains("-whatsNew") { showWhatsNew = true }
        }
        #endif
    }

    /// Mac and iPad have a pointer; iPhone doesn't.
    var showsPointerSettings: Bool {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .pad
        #else
        true
        #endif
    }
}
