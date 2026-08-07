import SwiftUI
import MapKit
import AnchorCore

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
    // Wind field and lore pins are exclusive layers: SwiftUI's Map silently
    // stops rendering ALL annotations above ~100 content items, and
    // grid (42) + places (44) + POIs (40) together blows that budget.
    @State private var showWind = true
    @State private var showPOIs = false
    @State private var useImagery = true

    var body: some View {
        // Rotation is locked: wind arrows are rotated in screen space and would
        // point the wrong geographic way on a rotated map.
        Map(position: $camera, interactionModes: [.pan, .zoom]) {
            if showWind {
                ForEach(Array(model.gridPoints.enumerated()), id: \.offset) { index, point in
                    if let sample = model.gridSample(at: index) {
                        Annotation("", coordinate: point.coordinate, anchor: .center) {
                            WindArrowView(sample: sample)
                        }
                        .annotationTitles(.hidden)
                    }
                }
            }
            if showPOIs {
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
            if showWind { WindLegend() }
        }
        .padding(.top, 4)
    }

    private var mapButtons: some View {
        VStack(spacing: 10) {
            Button {
                showWind.toggle()
                if showWind { showPOIs = false }
            } label: {
                Image(systemName: showWind ? "wind" : "wind.circle")
                    .symbolVariant(showWind ? .none : .slash)
            }
            Button {
                showPOIs.toggle()
                if showPOIs { showWind = false }
            } label: {
                Image(systemName: showPOIs ? "binoculars.fill" : "binoculars")
            }
            Button {
                useImagery.toggle()
            } label: {
                Image(systemName: useImagery ? "globe.americas.fill" : "map")
            }
            Button {
                Task { await model.refresh() }
            } label: {
                if model.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise")
                }
            }
        }
        .buttonStyle(.plain)
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(Theme.teal)
        .frame(width: 40)
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
        if let night = model.selectedNightDate {
            return "Where to stay — night of \(Fmt.nightLabel.string(from: night))"
        }
        return "Where should I stay?"
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
