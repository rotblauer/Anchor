import SwiftUI
import AnchorCore

/// Map pin for a live observing station — the "right now" ground truth.
struct BuoyMarkerView: View {
    let observation: BuoyObservation
    var selected = false

    var body: some View {
        VStack(spacing: 1) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.black.opacity(0.72))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(tint, lineWidth: selected ? 2.5 : 1.8)
                    )
                HStack(spacing: 3) {
                    Circle().fill(.green).frame(width: 5, height: 5)
                    Text(readout)
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 5)
            }
            .frame(width: 58, height: 22)
            Text("LIVE")
                .font(.system(size: 7, weight: .heavy))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.8), radius: 1.5)
        }
        .shadow(color: .black.opacity(0.4), radius: 2.5, y: 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(observation.stationName) live station, \(accessibilityReadout)")
        .accessibilityAddTraits(.isButton)
    }

    private var tint: Color {
        observation.windKt.map { Theme.windColor(kt: $0) } ?? .gray
    }

    private var readout: String {
        if let wind = observation.windKt {
            let direction = observation.windDirDeg.map { Compass.name(forDegrees: $0) } ?? ""
            return "\(direction) \(Int(wind.rounded()))kt"
        }
        if let wave = observation.waveHtFt {
            return String(format: "%.1f ft", wave)
        }
        return "—"
    }

    private var accessibilityReadout: String {
        if let wind = observation.windKt {
            let direction = observation.windDirDeg.map { Compass.name(forDegrees: $0) } ?? "unknown direction"
            return "wind \(Int(wind.rounded())) knots from \(direction)"
        }
        return "no wind data"
    }
}

/// Detail sheet: the live observation next to what the forecast claims for
/// the same spot and hour.
struct BuoyDetailSheet: View {
    @Environment(AppModel.self) private var model
    let observation: BuoyObservation

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Circle().fill(.green).frame(width: 9, height: 9)
                    Text("Live observation")
                        .font(.headline)
                    Spacer()
                    Text(age)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                    if let wind = observation.windKt {
                        row("Wind", "\(observation.windDirDeg.map { Compass.name(forDegrees: $0) + " " } ?? "")\(Int(wind.rounded())) kt")
                    }
                    if let gust = observation.gustKt {
                        row("Gusts", "\(Int(gust.rounded())) kt")
                    }
                    if let wave = observation.waveHtFt {
                        row("Waves", String(format: "%.1f ft", wave))
                    }
                    if let air = observation.airTempF {
                        row("Air", "\(Int(air.rounded())) °F")
                    }
                    if let water = observation.waterTempF {
                        row("Water", "\(Int(water.rounded())) °F")
                    }
                }

                if let forecast = model.forecastNear(lat: observation.lat, lon: observation.lon, at: observation.time) {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionHeader(title: "Forecast said", icon: "chart.line.uptrend.xyaxis")
                        Text("\(Fmt.windSummary(forecast)) at \(Fmt.hourLabel.string(from: forecast.time))")
                            .font(.callout)
                        if let delta = comparison(forecast: forecast) {
                            Text(delta)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(12)
                    .background(Theme.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                }

                Text("Station \(observation.stationId) · NOAA NDBC / GLOS. Land stations read lower than open water; trust the trend, verify with your own eyes.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle(observation.stationName)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var age: String {
        let minutes = observation.ageMinutes
        if minutes < 60 { return "\(minutes) min ago" }
        return "\(minutes / 60) h \(minutes % 60) min ago"
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.callout.weight(.semibold))
        }
    }

    private func comparison(forecast: WindSample) -> String? {
        guard let observed = observation.windKt else { return nil }
        let delta = forecast.speedKt - observed
        if abs(delta) < 3 { return "Model and reality agree within a few knots here." }
        if delta > 0 { return "The model is reading about \(Int(delta.rounded())) kt higher than this station right now." }
        return "The wind is running about \(Int((-delta).rounded())) kt above the model at this station — plan conservatively."
    }
}
