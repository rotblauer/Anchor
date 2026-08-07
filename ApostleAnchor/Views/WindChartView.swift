import SwiftUI
import Charts
import AnchorCore

/// Wind + gust line chart for one place, marking the selected forecast hour.
struct WindChartView: View {
    @Environment(AppModel.self) private var model
    let samples: [WindSample]

    private var window: [WindSample] {
        let start = max(0, model.selectedHourIndex - 6)
        let end = min(samples.count, start + 78)
        guard start < end else { return samples }
        return Array(samples[start..<end])
    }

    var body: some View {
        Chart {
            ForEach(window, id: \.time) { sample in
                AreaMark(
                    x: .value("Time", sample.time),
                    y: .value("Gust", sample.gustKt)
                )
                .foregroundStyle(Theme.teal.opacity(0.10))
                .interpolationMethod(.monotone)
            }
            ForEach(window, id: \.time) { sample in
                LineMark(
                    x: .value("Time", sample.time),
                    y: .value("Gust", sample.gustKt),
                    series: .value("Series", "Gust")
                )
                .foregroundStyle(Theme.teal.opacity(0.45))
                .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                .interpolationMethod(.monotone)
            }
            ForEach(window, id: \.time) { sample in
                LineMark(
                    x: .value("Time", sample.time),
                    y: .value("Wind", sample.speedKt),
                    series: .value("Series", "Wind")
                )
                .foregroundStyle(Theme.teal)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
                .interpolationMethod(.monotone)
            }
            if let selected = model.selectedTime,
               let first = window.first?.time, let last = window.last?.time,
               selected >= first, selected <= last {
                RuleMark(x: .value("Selected", selected))
                    .foregroundStyle(.orange.opacity(0.8))
                    .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [3, 3]))
            }
        }
        .chartYAxisLabel("knots")
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 12)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.weekday(.abbreviated).hour())
            }
        }
        .frame(height: 170)
        .environment(\.timeZone, Fmt.islandsTimeZone)

        HStack(spacing: 14) {
            Label("Wind", systemImage: "line.diagonal")
                .font(.caption2)
                .foregroundStyle(Theme.teal)
            Label("Gusts", systemImage: "line.diagonal")
                .font(.caption2)
                .foregroundStyle(Theme.teal.opacity(0.5))
            Spacer()
            Text("Times local to the islands")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
