import SwiftUI

/// One square per UTC day, a column per week (Monday on top), filled when that day's daily was solved.
struct DailyHeatmap: View {
    let solved: Set<String>
    @State private var width: CGFloat = 0

    private let cell: CGFloat = 14
    private let gap: CGFloat = 3
    private var weeks: Int { max(8, min(53, Int((width + gap) / (cell + gap)))) }

    var body: some View {
        let today = DailySchedule.key()
        let columns = Self.columns(weeks: weeks)
        let count = columns.joined().compactMap { $0 }.filter(solved.contains).count
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: gap) {
                ForEach(columns.indices, id: \.self) { c in
                    VStack(spacing: gap) {
                        ForEach(0..<7, id: \.self) { r in
                            square(columns[c][r], today: today)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            Text("\(count) solved in the last \(weeks) weeks")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Daily puzzles solved: \(count) in the last \(weeks) weeks")
    }

    @ViewBuilder
    private func square(_ key: String?, today: String) -> some View {
        let shape = RoundedRectangle(cornerRadius: 3)
        Group {
            if let key {
                shape.fill(solved.contains(key) ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.tertiary))
                    .overlay { if key == today { shape.strokeBorder(.primary.opacity(0.6), lineWidth: 1.5) } }
            } else {
                Color.clear
            }
        }
        .frame(width: cell, height: cell)
    }

    /// `weeks` columns of seven daily keys, ending with the current week; days after today are nil.
    private static func columns(weeks: Int, now: Date = .now) -> [[String?]] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        let weekday = calendar.component(.weekday, from: now) // 1 = Sunday
        let sinceMonday = (weekday + 5) % 7
        let firstMonday = now.addingTimeInterval(-Double(sinceMonday + 7 * (weeks - 1)) * 86_400)
        return (0..<weeks).map { w in
            (0..<7).map { d in
                let offset = w * 7 + d
                return offset > sinceMonday + 7 * (weeks - 1) ? nil
                    : DailySchedule.key(for: firstMonday.addingTimeInterval(Double(offset) * 86_400))
            }
        }
    }
}
