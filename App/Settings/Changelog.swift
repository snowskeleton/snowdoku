import Foundation

/// One version's entry in What's New (`Resources/Changelog.json`, newest first). It sums up
/// every build of the version, written before the next version is started.
struct ChangelogEntry: Decodable, Identifiable {
    let version: String
    /// When the entry was written, as `yyyy-MM-dd`.
    let date: String
    let summary: String?
    let items: [String]

    var id: String { version }

    var displayDate: String? {
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"
        return parser.date(from: date)?.formatted(date: .long, time: .omitted)
    }
}

enum Changelog {
    static let entries: [ChangelogEntry] = {
        guard let url = Bundle.main.url(forResource: "Changelog", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let list = try? JSONDecoder().decode([ChangelogEntry].self, from: data) else { return [] }
        return list
    }()

    /// "0.1 (5)": the running app's version and build number.
    static var currentVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}
