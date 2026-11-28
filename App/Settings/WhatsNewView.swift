import SwiftUI

/// What changed in each version, newest first, shown as a sheet from Settings.
struct WhatsNewView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                if Changelog.entries.isEmpty {
                    Text("No notes yet.")
                        .foregroundStyle(.secondary)
                }
                ForEach(Changelog.entries) { entry in
                    Section {
                        if let summary = entry.summary {
                            Text(summary)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(entry.items, id: \.self) { item in
                            Label {
                                Text(item)
                            } icon: {
                                Image(systemName: "circle.fill")
                                    .font(.system(size: 6))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        HStack(alignment: .firstTextBaseline) {
                            Text("Version \(entry.version)")
                            Spacer()
                            if let date = entry.displayDate { Text(date) }
                        }
                    }
                }
            }
            .navigationTitle("What's New")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        #if os(macOS)
        .frame(minWidth: 420, minHeight: 420)
        #endif
    }
}
