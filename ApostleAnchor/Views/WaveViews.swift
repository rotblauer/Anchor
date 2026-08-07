import SwiftUI
import Charts
import AnchorCore

/// Wave-field marker for one grid point: height in feet, with an arrow
/// pointing the direction the waves travel.
struct WaveMarkerView: View {
    let sample: WaveSample

    var body: some View {
        VStack(spacing: 1) {
            if let direction = sample.directionDeg {
                WindArrowShape()
                    .stroke(style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .foregroundStyle(Theme.waveColor(ft: sample.heightFt))
                    .frame(width: 13, height: 16)
                    .rotationEffect(.degrees(direction + 180))
                    .shadow(color: .black.opacity(0.6), radius: 1.5)
            }
            Text(String(format: "%.1f", sample.heightFt))
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.8), radius: 1.5)
        }
        .allowsHitTesting(false)
        .accessibilityLabel("Waves \(String(format: "%.1f", sample.heightFt)) feet")
    }
}

struct WaveLegend: View {
    private let stops: [(String, Double)] = [
        ("<1", 0.5), ("1–2", 1.5), ("2–4", 3), ("4–6", 5), ("6+", 7),
    ]

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "water.waves")
                .font(.caption2.bold())
            ForEach(stops, id: \.0) { label, ft in
                HStack(spacing: 3) {
                    Circle().fill(Theme.waveColor(ft: ft)).frame(width: 7, height: 7)
                    Text(label).font(.system(size: 9, weight: .medium))
                }
            }
            Text("ft").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: Capsule())
    }
}

/// Wave-height chart for one place, windowed around the selected hour.
struct WaveChartView: View {
    @Environment(AppModel.self) private var model
    let samples: [WaveSample]

    private var window: [WaveSample] {
        guard let selected = model.selectedTime else { return Array(samples.prefix(78)) }
        let start = selected.addingTimeInterval(-6 * 3600)
        let end = selected.addingTimeInterval(72 * 3600)
        return samples.filter { $0.time >= start && $0.time <= end }
    }

    var body: some View {
        Chart {
            ForEach(window, id: \.time) { sample in
                AreaMark(
                    x: .value("Time", sample.time),
                    y: .value("Waves", sample.heightFt)
                )
                .foregroundStyle(Theme.teal.opacity(0.15))
                .interpolationMethod(.monotone)
            }
            ForEach(window, id: \.time) { sample in
                LineMark(
                    x: .value("Time", sample.time),
                    y: .value("Waves", sample.heightFt)
                )
                .foregroundStyle(Theme.teal)
                .lineStyle(StrokeStyle(lineWidth: 2))
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
        .chartYAxisLabel("ft")
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 12)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: .dateTime.weekday(.abbreviated).hour())
            }
        }
        .frame(height: 110)
        .environment(\.timeZone, Fmt.islandsTimeZone)
    }
}

/// Where every number in the app comes from — one tap from the map.
struct DataSourcesSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Wind & gusts") {
                    row("Open-Meteo", "Hourly 10 m wind, gusts, and direction in knots, 8 days out, from blended national weather models. Free and open.",
                        link: "https://open-meteo.com")
                    if let updated = model.lastUpdated {
                        Label("Fetched \(Fmt.timestamp.string(from: updated))", systemImage: "clock")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Waves") {
                    row("Open-Meteo Marine", "Significant wave height, direction, and period from a regional wave model. Heights are open-water values — sheltered bays see less.",
                        link: "https://open-meteo.com/en/docs/marine-weather-api")
                }
                Section("Marine alerts") {
                    row("NOAA / National Weather Service", "Active Small Craft Advisories and Gale Warnings for the five nearshore zones around the Apostles (LSZ121, 146, 147, 148, 150).",
                        link: "https://www.weather.gov/dlh/")
                }
                Section("Places & lore") {
                    row("NPS, NOAA & cruising references", "Anchorages, docks, marinas, and points of interest compiled from NPS boating guidance, the NOAA Coast Pilot, Wisconsin Shipwrecks, marina listings, and published Lake Superior cruising references. Each entry cites its sources.",
                        link: "https://www.nps.gov/apis/planyourvisit/boating.htm")
                }
                Section {
                    Text("Not for navigation. Forecasts are guidance — carry charts and make your own seamanship calls.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Data sources")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func row(_ title: String, _ detail: String, link: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let url = URL(string: link) {
                Link(title, destination: url)
                    .font(.subheadline.weight(.semibold))
            } else {
                Text(title).font(.subheadline.weight(.semibold))
            }
            Text(detail).font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}
