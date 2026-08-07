import SwiftUI
import AnchorCore

/// Ranked list of where to stay, for a stay of 1–7 nights starting on the
/// currently selected night. Multi-night stays are scored as a whole window
/// with the worst night binding, so "best for 3 nights" means genuinely
/// livable on all three — not great tonight and grim on Sunday.
struct RecommendationsSheet: View {
    @Environment(AppModel.self) private var model
    @AppStorage("stay.length") private var stayLength = 1
    @AppStorage("stay.includeAnchorages") private var includeAnchorages = true
    @AppStorage("stay.includeDocks") private var includeDocks = true
    @AppStorage("stay.includeMarinas") private var includeMarinas = true

    private var filter: PlaceTypeFilter {
        PlaceTypeFilter(includeAnchorages: includeAnchorages,
                        includeDocks: includeDocks,
                        includeMarinas: includeMarinas)
    }

    var body: some View {
        NavigationStack {
            Group {
                let maxNights = min(7, model.maxPlannableNights)
                let effectiveLength = min(max(1, stayLength), maxNights)
                let options = model.rankedForStay(nightCount: effectiveLength, filter: filter)
                if options.isEmpty {
                    emptyState
                } else {
                    List {
                        Section {
                            VStack(alignment: .leading, spacing: 8) {
                                stayPicker(maxNights: maxNights, selected: effectiveLength)
                                filterChips
                            }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        }
                        Section {
                            ForEach(Array(options.prefix(20).enumerated()), id: \.element.place.id) { index, option in
                                NavigationLink {
                                    PlaceDetailView(place: option.place)
                                } label: {
                                    StayOptionRow(
                                        rank: index + 1,
                                        option: option,
                                        streak: effectiveLength == 1 ? model.stayNights(for: option.place.id) : nil
                                    )
                                }
                            }
                        } header: {
                            if let night = model.selectedNightDate {
                                Text(effectiveLength == 1
                                     ? "Night of \(Fmt.nightLabel.string(from: night)) — best first"
                                     : "\(effectiveLength) nights from \(Fmt.nightLabel.string(from: night)) — best first")
                            }
                        } footer: {
                            Text(effectiveLength == 1
                                 ? "Scores weigh overnight wind against each spot's shelter and wave fetch. Nights count consecutive Good-or-better nights starting with this one."
                                 : "Each stay is scored across all \(effectiveLength) nights with the worst night weighted heaviest — one bad night sinks a stay. Spots the forecast can't cover for the whole window aren't listed.")
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Where to stay")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func stayPicker(maxNights: Int, selected: Int) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(1...max(1, maxNights), id: \.self) { nights in
                    Button {
                        stayLength = nights
                    } label: {
                        Text(nights == 1 ? "1 night" : "\(nights) nights")
                            .font(.caption.weight(selected == nights ? .bold : .regular))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selected == nights ? Theme.teal : Color.secondary.opacity(0.15), in: Capsule())
                            .foregroundStyle(selected == nights ? .white : .primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Text("Include:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                typeChip("Anchorages", isOn: $includeAnchorages)
                typeChip("Docks", isOn: $includeDocks)
                typeChip("Marinas", isOn: $includeMarinas)
            }
            .padding(.horizontal, 16)
        }
    }

    private func typeChip(_ label: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isOn.wrappedValue ? "checkmark.circle.fill" : "circle")
                    .font(.caption2)
                Text(label)
            }
            .font(.caption.weight(isOn.wrappedValue ? .semibold : .regular))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(isOn.wrappedValue ? Theme.teal.opacity(0.15) : Color.secondary.opacity(0.10), in: Capsule())
            .foregroundStyle(isOn.wrappedValue ? Theme.teal : .secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(label) \(isOn.wrappedValue ? "included" : "excluded")")
    }

    private var emptyState: some View {
        Group {
            if !includeAnchorages && !includeDocks && !includeMarinas {
                ContentUnavailableView {
                    Label("Nothing to rank", systemImage: "line.3.horizontal.decrease.circle")
                } description: {
                    Text("Every place type is filtered out.")
                } actions: {
                    Button("Include everything") {
                        includeAnchorages = true
                        includeDocks = true
                        includeMarinas = true
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.teal)
                }
            } else if model.hours.isEmpty {
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
        }
    }
}

struct StayOptionRow: View {
    let rank: Int
    let option: StayOption
    let streak: Int?

    var body: some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.subheadline.bold().monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 22)

            ZStack {
                Circle().fill(Theme.color(for: option.band).opacity(0.18))
                PlaceTypeIcon(type: option.place.type)
                    .foregroundStyle(Theme.color(for: option.band))
                    .frame(width: 16, height: 16)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(option.place.name).font(.subheadline.weight(.semibold))
                Text("\(option.place.island) · \(option.place.type.label)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let worst = option.worstNight {
                    Text("Toughest night: \(Fmt.nightLabel.string(from: worst.nightOf)) — \(worst.band.label)")
                        .font(.caption2)
                        .foregroundStyle(Theme.color(for: worst.band))
                } else if let reason = option.nights.first?.reasons.first {
                    Text(reason)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 4) {
                BandChip(band: option.band, compact: true)
                if let streak, streak > 0 {
                    StayBadge(nights: streak)
                } else if option.nights.count > 1 {
                    OutlookStrip(nights: option.nights, compact: true)
                }
            }
        }
        .padding(.vertical, 2)
    }
}
