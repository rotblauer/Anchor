import SwiftUI

struct AboutView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Apostle Anchor")
                            .font(.title2.bold())
                        Text("Plans where to anchor or dock in the Apostle Islands by matching multi-day wind forecasts against each spot's real-world shelter — the way experienced Superior sailors read a blow.")
                            .font(.callout)
                    }
                    .padding(.vertical, 4)
                }

                Section("How ratings work") {
                    Label {
                        Text("Every place carries a 16-direction shelter profile and wave-fetch map built from its actual geography.")
                    } icon: {
                        Image(systemName: "safari").foregroundStyle(Theme.teal)
                    }
                    Label {
                        Text("Hourly wind and gust forecasts are scored against that profile, weighting the overnight hours you'd actually swing at anchor (6 PM–9 AM).")
                    } icon: {
                        Image(systemName: "moon.stars.fill").foregroundStyle(.indigo)
                    }
                    Label {
                        Text("Strong wind onto an exposed spot — a lee shore — caps the score no matter what. That's the one rule Superior doesn't forgive.")
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    }
                    Label {
                        Text("Night squares project a week out, so you can pick a spot that stays good for your whole stay.")
                    } icon: {
                        Image(systemName: "calendar").foregroundStyle(.green)
                    }
                }

                Section("Data") {
                    row("Forecasts", "Open-Meteo (hourly wind, gusts, direction; 8 days)")
                    row("Marine alerts", "NOAA / National Weather Service (api.weather.gov)")
                    row("Places", "NPS Apostle Islands boating guidance, marina listings, and published Lake Superior cruising references — nothing invented")
                    row("Times", "Shown in the islands' local time (Central)")
                    if let updated = model.lastUpdated {
                        row("Forecast fetched", Fmt.timestamp.string(from: updated))
                    }
                }

                Section {
                    Text("Not for navigation. Ratings are planning guidance, not gospel — carry charts, watch the sky, and make your own seamanship calls. Lake Superior is cold, big, and changes faster than any forecast.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("The fine print")
                }
            }
            .navigationTitle("About")
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.callout)
        }
        .padding(.vertical, 2)
    }
}
