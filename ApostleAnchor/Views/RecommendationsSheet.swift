import SwiftUI
import AnchorCore

/// Ranked list of where to stay for the currently selected night, with
/// multi-night stay potential so users can weigh one-night wonders against
/// spots that stay good all week.
struct RecommendationsSheet: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            Group {
                let ranked = model.ranked()
                if ranked.isEmpty {
                    if model.hours.isEmpty {
                        ContentUnavailableView(
                            "No forecast yet",
                            systemImage: "wind",
                            description: Text("Fetch the forecast from the map screen, then come back for picks.")
                        )
                    } else {
                        ContentUnavailableView {
                            Label("This night has already ended", systemImage: "moon.zzz")
                        } description: {
                            Text("The scrubber is pointing at a night that's over.")
                        } actions: {
                            Button("Jump to tonight") { model.jumpToNow() }
                                .buttonStyle(.borderedProminent)
                                .tint(Theme.teal)
                        }
                    }
                } else {
                    List {
                        Section {
                            ForEach(Array(ranked.prefix(20).enumerated()), id: \.element.place.id) { index, entry in
                                NavigationLink {
                                    PlaceDetailView(place: entry.place)
                                } label: {
                                    RecommendationRow(rank: index + 1, entry: entry)
                                }
                            }
                        } header: {
                            if let night = model.selectedNightDate {
                                Text("Night of \(Fmt.nightLabel.string(from: night)) — best first")
                            }
                        } footer: {
                            Text("Scores weigh overnight wind against each spot's shelter and wave fetch. Nights count consecutive Good-or-better nights starting with this one.")
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Where to stay")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct RecommendationRow: View {
    let rank: Int
    let entry: (place: Place, night: NightAssessment, stayNights: Int)

    var body: some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 22)

            ZStack {
                Circle().fill(Theme.color(for: entry.night.band).opacity(0.18))
                PlaceTypeIcon(type: entry.place.type)
                    .foregroundStyle(Theme.color(for: entry.night.band))
                    .frame(width: 16, height: 16)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.place.name).font(.subheadline.weight(.semibold))
                Text("\(entry.place.island) · \(entry.place.type.label)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let reason = entry.night.reasons.first {
                    Text(reason)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 4) {
                BandChip(band: entry.night.band, compact: true)
                StayBadge(nights: entry.stayNights)
            }
        }
        .padding(.vertical, 2)
    }
}
