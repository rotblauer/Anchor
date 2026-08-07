import SwiftUI
import AnchorCore

/// Browsable catalog of every anchorage, dock, and marina.
struct PlacesListView: View {
    @Environment(AppModel.self) private var model
    @State private var searchText = ""
    @State private var filter: Filter = .all

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

    private var filtered: [Place] {
        model.places.filter { place in
            filter.matches(place)
                && (searchText.isEmpty
                    || place.name.localizedCaseInsensitiveContains(searchText)
                    || place.island.localizedCaseInsensitiveContains(searchText))
        }
    }

    private var grouped: [(island: String, places: [Place])] {
        Dictionary(grouping: filtered, by: \.island)
            .map { (island: $0.key, places: $0.value.sorted { $0.name < $1.name }) }
            .sorted { lhs, rhs in
                let lhsMainland = lhs.island.hasPrefix("Mainland")
                let rhsMainland = rhs.island.hasPrefix("Mainland")
                if lhsMainland != rhsMainland { return !lhsMainland }
                return lhs.island < rhs.island
            }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Filter", selection: $filter) {
                        ForEach(Filter.allCases, id: \.self) { Text($0.rawValue) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                ForEach(grouped, id: \.island) { group in
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
            .navigationTitle("Places to stay")
            .searchable(text: $searchText, prompt: "Search bays, docks, islands")
            .overlay {
                if filtered.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }
}

struct PlaceRow: View {
    @Environment(AppModel.self) private var model
    let place: Place

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
                Text(place.type.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

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
}
