import Foundation

/// Solve reports waiting to be uploaded, kept in a JSON file in Application Support. Nothing sends
/// them yet: when the server exists, an uploader posts `pending` and calls `remove` with the IDs
/// the server acknowledged. (It should also ask for consent first.)
@MainActor
final class ReportQueue {
    /// Oldest reports are dropped beyond this, so an app that never uploads stays small.
    static let limit = 500

    private(set) var pending: [SolveReport] = []
    private let url: URL?

    /// A random ID for this install, sent with each report so the server can tell one player's
    /// solves apart (and weigh them by that player's skill) without knowing who they are.
    let installID: UUID

    init(directory: URL? = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first) {
        url = directory?.appending(path: "Snowdoku", directoryHint: .isDirectory).appending(path: "pending-reports.json")
        let defaults = UserDefaults.standard
        if let s = defaults.string(forKey: "installID"), let id = UUID(uuidString: s) {
            installID = id
        } else {
            installID = UUID()
            defaults.set(installID.uuidString, forKey: "installID")
        }
        if let url, let data = try? Data(contentsOf: url) {
            pending = (try? JSONDecoder().decode([SolveReport].self, from: data)) ?? []
        }
    }

    func enqueue(_ r: SolveReport) {
        pending.removeAll { $0.id == r.id }
        pending.append(r)
        if pending.count > Self.limit { pending.removeFirst(pending.count - Self.limit) }
        save()
    }

    /// Drops reports the server has stored.
    func remove(_ ids: Set<UUID>) {
        pending.removeAll { ids.contains($0.id) }
        save()
    }

    private func save() {
        guard let url, let data = try? JSONEncoder().encode(pending) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
