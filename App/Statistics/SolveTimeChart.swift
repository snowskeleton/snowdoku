import Charts
import SwiftUI

/// Each solve's time in order, with a rolling average and the best hint-free time.
struct SolveTimeChart: View {
    /// Oldest first.
    let solves: [SolveRecord]
    var window = 5

    private struct Point: Identifiable {
        let id: Int
        let seconds: Double
        let average: Double
        let hinted: Bool
    }

    private var points: [Point] {
        solves.indices.map { i in
            let slice = solves[max(0, i - window + 1)...i]
            return Point(id: i + 1, seconds: solves[i].seconds,
                         average: slice.map(\.seconds).reduce(0, +) / Double(slice.count),
                         hinted: solves[i].hintsUsed > 0)
        }
    }

    var body: some View {
        let best = solves.filter { $0.hintsUsed == 0 }.map(\.seconds).min()
        Chart {
            ForEach(points) { p in
                PointMark(x: .value("Solve", p.id), y: .value("Time", p.seconds))
                    .foregroundStyle(by: .value("Kind", p.hinted ? "With hints" : "No hints"))
                    .symbolSize(30)
            }
            ForEach(points) { p in
                LineMark(x: .value("Solve", p.id), y: .value("Time", p.average), series: .value("Series", "Average"))
                    .foregroundStyle(.primary.opacity(0.7))
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2))
            }
            if let best {
                RuleMark(y: .value("Best", best))
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, alignment: .leading) {
                        Text("Best \(formatTime(best))").font(.caption2).foregroundStyle(.green)
                    }
            }
        }
        .chartForegroundStyleScale(["No hints": AnyShapeStyle(.tint), "With hints": AnyShapeStyle(.orange)])
        .chartLegend(position: .top, alignment: .leading)
        .chartXAxisLabel("Solve")
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel { if let s = value.as(Double.self) { Text(formatTime(s)) } }
            }
        }
        .chartYScale(domain: .automatic(includesZero: true))
        .frame(height: 220)
    }
}
