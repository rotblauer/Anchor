import SwiftUI
import MapKit
import AnchorCore

/// The map shows one field layer at a time — wind, waves, or lore pins —
/// because SwiftUI's Map silently stops rendering ALL annotations above
/// ~100 content items, and grid (42) + places (44) + POIs (40) together
/// would blow that budget.
enum PlanMapLayer: String, CaseIterable {
    case wind, waves, lore

    var symbol: String {
        switch self {
        case .wind: return "wind"
        case .waves: return "water.waves"
        case .lore: return "binoculars.fill"
        }
    }

    var label: String {
        switch self {
        case .wind: return "Wind layer"
        case .waves: return "Wave layer"
        case .lore: return "Landmarks layer"
        }
    }
}

struct PlanMapView: View {
    @Environment(AppModel.self) private var model
    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: WindGrid.regionCenter.lat,
                                           longitude: WindGrid.regionCenter.lon),
            span: MKCoordinateSpan(latitudeDelta: WindGrid.regionLatSpan,
                                   longitudeDelta: WindGrid.regionLonSpan)
        )
    )
    @State private var selectedPlace: Place?
    @State private var selectedPOI: PointOfInterest?
    @State private var showRecommendations = false
    @State private var showDataSources = false
    @State private var layer: PlanMapLayer = .wind
    @State private var useImagery = true
    @AppStorage("stay.length") private var stayLength = 1

    var body: some View {
        Map(position: $camera, interactionModes: [.pan, .zoom]) {
            switch layer {
            case .wind:
                ForEach(Array(model.gridPoints.enumerated()), id: \.offset) { index, point in
                    if let sample = model.gridSample(at: index) {
                        Annotation("", coordinate: point.coordinate, anchor: .center) {
                            WindArrowView(sample: sample)
                        }
                        .annotationTitles(.hidden)
                    }
                }
            case .waves:
                ForEach(Array(model.gridPoints.enumerated()), id: \.offset) { index, point in
                    if let sample = model.gridWaveSample(at: index) {
                        Annotation("", coordinate: point.coordinate, anchor: .center) {
                            WaveMarkerView(sample: sample)
                        }
                        .annotationTitles(.hidden)
                    }
                }
            case .lore:
                ForEach(model.pois) { poi in
                    Annotation("", coordinate: poi.coordinate, anchor: .center) {
                        POIMarkerView(poi: poi, selected: selectedPOI?.id == poi.id)
                            .onTapGesture { selectedPOI = poi }
                    }
                    .annotationTitles(.hidden)
                }
            }
            ForEach(model.places) { place in
                Annotation("", coordinate: place.coordinate, anchor: .center) {
                    PlaceMarkerView(
                        place: place,
                        band: model.hourScore(for: place)?.band,
                        selected: selectedPlace?.id == place.id
                    )
                    .onTapGesture { selectedPlace = place }
                }
                .annotationTitles(.hidden)
            }
        }
        .mapStyle(useImagery ? .imagery(elevation: .realistic) : .standard(elevation: .realistic))
        .mapControls {
            MapScaleView()
        }
        .overlay(alignment: .top) { topOverlay }
        .overlay(alignment: .topTrailing) { mapButtons }
        .safeAreaInset(edge: .bottom) { bottomBar }
        .sheet(item: $selectedPlace) { place in
            NavigationStack {
                PlaceDetailView(place: place)
            }
            .presentationDetents([.medium, .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .sheet(item: $selectedPOI) { poi in
            NavigationStack {
                POIDetailView(poi: poi)
            }
            .presentationDetents([.medium, .large])
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
        }
        .sheet(isPresented: $showRecommendations) {
            RecommendationsSheet()
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $showDataSources) {
            DataSourcesSheet()
                .presentationDetents([.medium, .large])
        }
    }

    private var topOverlay: some View {
        VStack(spacing: 6) {
            ForEach(model.alerts) { alert in
                Label(alert.event, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.red.opacity(0.92), in: Capsule())
                    .foregroundStyle(.white)
            }
            if let error = model.loadError {
                Text(error)
                    .font(.caption)
                    .padding(8)
                    .background(.orange.opacity(0.92), in: RoundedRectangle(cornerRadius: 8))
                    .foregroundStyle(.white)
            }
            switch layer {
            case .wind: WindLegend()
            case .waves: WaveLegend()
            case .lore: EmptyView()
            }
            attributionChip
        }
        .padding(.top, 4)
    }

    private var attributionChip: some View {
        Button {
            showDataSources = true
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "info.circle")
                Text(attributionText)
            }
            .font(.system(size: 10, weight: .medium))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: Capsule())
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Data sources")
    }

    private var attributionText: String {
        let source = layer == .waves ? "Waves: Open-Meteo Marine" : "Wind: Open-Meteo"
        if let updated = model.lastUpdated {
            return "\(source) · \(Fmt.timestamp.string(from: updated))"
        }
        return source
    }

    private var mapButtons: some View {
        VStack(spacing: 10) {
            ForEach(PlanMapLayer.allCases, id: \.self) { candidate in
                Button {
                    layer = candidate
                } label: {
                    Image(systemName: candidate.symbol)
                        .foregroundStyle(layer == candidate ? Color.white : Theme.teal)
                        .frame(width: 30, height: 26)
                        .background(
                            layer == candidate ? Theme.teal : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                }
                .accessibilityLabel(candidate.label)
                .accessibilityAddTraits(layer == candidate ? .isSelected : [])
            }
            Divider().frame(width: 26)
            Button {
                useImagery.toggle()
            } label: {
                Image(systemName: useImagery ? "globe.americas.fill" : "map")
            }
            .accessibilityLabel(useImagery ? "Switch to standard map" : "Switch to satellite map")
            Button {
                Task { await model.refresh() }
            } label: {
                if model.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
            .accessibilityLabel("Refresh forecast")
        }
        .buttonStyle(.plain)
        .font(.system(size: 16, weight: .semibold))
        .foregroundStyle(Theme.teal)
        .frame(width: 44)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.trailing, 8)
        .padding(.top, 60)
    }

    private var bottomBar: some View {
        VStack(spacing: 8) {
            Button {
                showRecommendations = true
            } label: {
                Label(recommendationTitle, systemImage: "checkmark.seal.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.teal)

            TimeScrubber()
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .background(.thinMaterial)
    }

    private var recommendationTitle: String {
        guard let night = model.selectedNightDate else { return "Where should I stay?" }
        let nights = max(1, stayLength)
        if nights == 1 {
            return "Where to stay — night of \(Fmt.nightLabel.string(from: night))"
        }
        return "Where to stay — \(nights) nights from \(Fmt.nightLabel.string(from: night))"
    }
}

struct WindLegend: View {
    private let stops: [(String, Double)] = [
        ("<7", 5), ("7–12", 9), ("12–17", 14), ("17–22", 19), ("22–28", 25), ("28+", 30),
    ]

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "wind")
                .font(.caption2.bold())
            ForEach(stops, id: \.0) { label, kt in
                HStack(spacing: 3) {
                    Circle().fill(Theme.windColor(kt: kt)).frame(width: 7, height: 7)
                    Text(label).font(.system(size: 9, weight: .medium))
                }
            }
            Text("kt").font(.system(size: 9, weight: .medium)).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(.regularMaterial, in: Capsule())
    }
}
