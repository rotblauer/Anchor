import SwiftUI
import AnchorCore

/// Browsable catalog: places to stay and the lore layer, side by side.
/// Stay mode can organize anchorages by shelter for any wind direction —
/// built for the boater whose only input is a VHF wind report.
struct PlacesListView: View {
    @Environment(AppModel.self) private var model
    @State private var searchText = ""
    @AppStorage("places.mode") private var mode = "stay"
    @State private var filter: Filter = .all
    @State private var poiKind: POIKind?
    @AppStorage("places.sortByWind") private var sortByWind = false
    /// Selected 16-sector index for the wind organizer; nil = follow forecast.
    @State private var windSectorIndex: Int?

    enum Filter: String, CaseIterable {
        case all = "All"
        case anchorages = "Anchorages"
        case docks = "Docks"
        case marinas = "Marinas"

        func matches(_ place: Place) -> Bool {
            switch self {
            case .all: return true
            case .anchorages: return place.canAnchor
            case .docks: return place.type == .dock || place.type == .anchorageDock
            case .marinas: return place.type == .marina
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Browse", selection: $mode) {
                        Text("Places to stay").tag("stay")
                        Text("Lore").tag("lore")
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                if mode == "stay" {
                    stayContent
                } else {
                    loreContent
                }
            }
            .navigationTitle(mode == "stay" ? "Places to stay" : "Legends & landmarks")
            .searchable(text: $searchText, prompt: mode == "stay" ? "Search bays, docks, islands" : "Search lighthouses, wrecks, lore")
        }
    }

    // MARK: - Stay mode

    private var filteredPlaces: [Place] {
        model.places.filter { place in
            filter.matches(place)
                && (searchText.isEmpty
                    || place.name.localizedCaseInsensitiveContains(searchText)
                    || place.island.localizedCaseInsensitiveContains(searchText))
        }
    }

    private var organizerDirectionDeg: Double {
        if let index = windSectorIndex { return Double(index) * 22.5 }
        return model.currentWindDirectionDeg ?? 270
    }

    @ViewBuilder
    private var stayContent: some View {
        Section {
            Picker("Filter", selection: $filter) {
                ForEach(Filter.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            windOrganizerControls
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 2, trailing: 0))
        }

        if sortByWind {
            Section {
                let direction = organizerDirectionDeg
                let ranked = filteredPlaces
                    .map { place in (place, Compass.interpolate(place.shelter, atDegrees: direction)) }
                    .sorted { $0.1 > $1.1 }
                ForEach(ranked, id: \.0.id) { place, shelterValue in
                    NavigationLink {
                        PlaceDetailView(place: place)
                    } label: {
                        PlaceRow(place: place,
                                 roseArrowDeg: direction,
                                 shelterPercent: Int((shelterValue * 100).rounded()))
                    }
                }
            } header: {
                Text("Most sheltered from \(Compass.name(forDegrees: organizerDirectionDeg)) first")
            } footer: {
                Text("Percentages are each spot's protection from wind blowing out of the chosen direction. Rose arrows show that wind; green petals mean shelter.")
            }
        } else {
            ForEach(groupedPlaces, id: \.island) { group in
                Section(group.island) {
                    ForEach(group.places) { place in
                        NavigationLink {
                            PlaceDetailView(place: place)
                        } label: {
                            PlaceRow(place: place)
                        }
                    }
                }
            }
        }

        if filteredPlaces.isEmpty {
            Section {
                ContentUnavailableView.search(text: searchText)
                    .listRowBackground(Color.clear)
            }
        }
    }

    private var groupedPlaces: [(island: String, places: [Place])] {
        Dictionary(grouping: filteredPlaces, by: \.island)
            .map { (island: $0.key, places: $0.value.sorted { $0.name < $1.name }) }
            .sorted { lhs, rhs in
                let lhsMainland = lhs.island.hasPrefix("Mainland")
                let rhsMainland = rhs.island.hasPrefix("Mainland")
                if lhsMainland != rhsMainland { return !lhsMainland }
                return lhs.island < rhs.island
            }
    }

    private var windOrganizerControls: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.snappy) { sortByWind.toggle() }
            } label: {
                Label(sortByWind ? "Organized by shelter from \(Compass.name(forDegrees: organizerDirectionDeg))" : "Organize by wind direction",
                      systemImage: "safari")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(sortByWind ? Theme.teal : Color.secondary.opacity(0.12), in: Capsule())
                    .foregroundStyle(sortByWind ? .white : .primary)
                    .frame(minHeight: 36)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(sortByWind ? .isSelected : [])

            if sortByWind {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 5) {
                        directionChip(nil, label: forecastChipLabel)
                        ForEach(0..<16, id: \.self) { index in
                            directionChip(index, label: Compass.sectorNames[index])
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    private var forecastChipLabel: String {
        if let direction = model.currentWindDirectionDeg {
            return "Now (\(Compass.name(forDegrees: direction)))"
        }
        return "Now"
    }

    private func directionChip(_ index: Int?, label: String) -> some View {
        let isSelected = windSectorIndex == index
        return Button {
            windSectorIndex = index
        } label: {
            Text(label)
                .font(.caption2.weight(isSelected ? .bold : .regular))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(isSelected ? Theme.teal : Color.secondary.opacity(0.12), in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(minHeight: 32)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(index == nil ? "Use current forecast wind" : "Wind from \(label)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Lore mode

    private var filteredPois: [PointOfInterest] {
        model.pois.filter { poi in
            (poiKind == nil || poi.kind == poiKind)
                && (searchText.isEmpty
                    || poi.name.localizedCaseInsensitiveContains(searchText)
                    || poi.island.localizedCaseInsensitiveContains(searchText)
                    || poi.tagline.localizedCaseInsensitiveContains(searchText))
        }
    }

    @ViewBuilder
    private var loreContent: some View {
        Section {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    loreKindChip(nil, label: "All", symbol: "mappin.and.ellipse")
                    ForEach(POIKind.allCases.filter { kind in model.pois.contains { $0.kind == kind } }, id: \.self) { kind in
                        loreKindChip(kind, label: kind.label, symbol: kind.symbol)
                    }
                }
                .padding(.horizontal, 2)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        }

        ForEach(groupedPois, id: \.island) { group in
            Section(group.island) {
                ForEach(group.pois) { poi in
                    NavigationLink {
                        POIDetailView(poi: poi)
                    } label: {
                        POIRow(poi: poi)
                    }
                }
            }
        }

        if filteredPois.isEmpty {
            Section {
                ContentUnavailableView.search(text: searchText)
                    .listRowBackground(Color.clear)
            }
        }
    }

    private var groupedPois: [(island: String, pois: [PointOfInterest])] {
        Dictionary(grouping: filteredPois, by: \.island)
            .map { (island: $0.key, pois: $0.value.sorted { $0.name < $1.name }) }
            .sorted { lhs, rhs in
                let lhsMainland = lhs.island.hasPrefix("Mainland")
                let rhsMainland = rhs.island.hasPrefix("Mainland")
                if lhsMainland != rhsMainland { return !lhsMainland }
                return lhs.island < rhs.island
            }
    }

    private func loreKindChip(_ kind: POIKind?, label: String, symbol: String) -> some View {
        let isSelected = poiKind == kind
        return Button {
            withAnimation(.snappy) { poiKind = kind }
        } label: {
            Label(label, systemImage: symbol)
                .font(.caption.weight(isSelected ? .bold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Theme.teal : Color.secondary.opacity(0.12), in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
                .frame(minHeight: 32)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct PlaceRow: View {
    @Environment(AppModel.self) private var model
    let place: Place
    /// Wind direction for the mini rose arrow; defaults to the selected-hour forecast.
    var roseArrowDeg: Double?
    /// When set (wind-organizer mode), shows the shelter percentage prominently.
    var shelterPercent: Int?

    var body: some View {
        let night = model.selectedNight(for: place.id)
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(Theme.color(for: night?.band).opacity(0.16))
                PlaceTypeIcon(type: place.type)
                    .foregroundStyle(Theme.color(for: night?.band))
                    .frame(width: 15, height: 15)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(place.name).font(.subheadline.weight(.medium))
                Text(shelterPercent == nil ? place.type.label : "\(place.island) · \(place.type.label)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if let shelterPercent {
                Text("\(shelterPercent)%")
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(Color(hue: 0.02 + 0.34 * Double(shelterPercent) / 100, saturation: 0.75, brightness: 0.65))
            }

            MiniProtectionRose(
                shelter: place.shelter,
                arrowDeg: roseArrowDeg ?? model.sample(for: place.id)?.directionDeg
            )

            if shelterPercent == nil {
                VStack(alignment: .trailing, spacing: 3) {
                    if place.advisory {
                        AdvisoryChip(compact: true)
                    } else {
                        BandChip(band: night?.band, compact: true)
                        if let outlook = model.outlooks[place.id] {
                            OutlookStrip(nights: outlook.nights, compact: true)
                        }
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(shelterPercent.map { "\($0) percent sheltered" } ?? "")
    }
}
