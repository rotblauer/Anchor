import SwiftUI
import AnchorCore

/// The fun half of the app: island stories, lighthouses, sea caves, and lore.
struct ExploreView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let park = model.content?.park {
                        ParkCard(
                            title: "Apostle Islands National Lakeshore",
                            icon: "leaf.fill",
                            text: park.overview,
                            gradient: [Theme.deepWater, Theme.teal]
                        )
                        ParkCard(
                            title: "The Sea Caves",
                            icon: "water.waves",
                            text: park.seaCaves,
                            gradient: [Color(red: 0.5, green: 0.25, blue: 0.15), Color(red: 0.8, green: 0.5, blue: 0.3)]
                        )
                        ParkCard(
                            title: "Boating Superior",
                            icon: "sailboat.fill",
                            text: park.boatingSafety,
                            gradient: [Color(red: 0.1, green: 0.3, blue: 0.45), Color(red: 0.2, green: 0.55, blue: 0.6)]
                        )
                    }

                    if !model.pois.isEmpty {
                        legendsSection
                    }

                    Text("The Islands")
                        .font(.title3.bold())
                        .padding(.top, 4)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(model.content?.islands ?? []) { island in
                            NavigationLink {
                                IslandDetailView(island: island)
                            } label: {
                                IslandCard(island: island)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Explore")
        }
    }

    @State private var poiFilter: POIKind?

    private var filteredPois: [PointOfInterest] {
        let pois = poiFilter.map { kind in model.pois.filter { $0.kind == kind } } ?? model.pois
        return pois.sorted {
            if $0.kind != $1.kind { return $0.kind.rawValue < $1.kind.rawValue }
            return $0.name < $1.name
        }
    }

    private var legendsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Legends & Landmarks")
                .font(.title3.bold())
                .padding(.top, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    filterChip(nil, label: "All", symbol: "mappin.and.ellipse")
                    ForEach(POIKind.allCases.filter { kind in model.pois.contains { $0.kind == kind } }, id: \.self) { kind in
                        filterChip(kind, label: kind.label, symbol: kind.symbol)
                    }
                }
            }

            LazyVStack(spacing: 2) {
                ForEach(filteredPois) { poi in
                    NavigationLink {
                        POIDetailView(poi: poi)
                    } label: {
                        POIRow(poi: poi)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func filterChip(_ kind: POIKind?, label: String, symbol: String) -> some View {
        let isSelected = poiFilter == kind
        return Button {
            withAnimation(.snappy) { poiFilter = kind }
        } label: {
            Label(label, systemImage: symbol)
                .font(.caption.weight(isSelected ? .bold : .regular))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isSelected ? Theme.teal : Color.secondary.opacity(0.12), in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

struct ParkCard: View {
    let title: String
    let icon: String
    let text: String
    let gradient: [Color]
    @State private var expanded = false

    var body: some View {
        Button {
            withAnimation(.snappy) { expanded.toggle() }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label(title, systemImage: icon)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.bold())
                        .foregroundStyle(.white.opacity(0.7))
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                }
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(expanded ? nil : 3)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(
                LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 14)
            )
        }
        .buttonStyle(.plain)
        .accessibilityHint(expanded ? "Collapses the text" : "Expands the full text")
    }
}

struct IslandCard: View {
    let island: IslandInfo

    private var gradient: [Color] {
        let palettes: [[Color]] = [
            [Color(red: 0.08, green: 0.35, blue: 0.42), Color(red: 0.16, green: 0.55, blue: 0.52)],
            [Color(red: 0.13, green: 0.25, blue: 0.45), Color(red: 0.25, green: 0.45, blue: 0.65)],
            [Color(red: 0.35, green: 0.22, blue: 0.15), Color(red: 0.6, green: 0.42, blue: 0.25)],
            [Color(red: 0.12, green: 0.4, blue: 0.3), Color(red: 0.3, green: 0.6, blue: 0.4)],
            [Color(red: 0.3, green: 0.2, blue: 0.4), Color(red: 0.5, green: 0.4, blue: 0.6)],
        ]
        var hash = 0
        for scalar in island.name.unicodeScalars { hash = (hash &* 31 &+ Int(scalar.value)) }
        return palettes[abs(hash) % palettes.count]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if island.lighthouse != nil {
                Image(systemName: "light.beacon.max.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
            } else {
                Image(systemName: "tree.fill")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
            }
            Spacer(minLength: 0)
            Text(island.name.replacingOccurrences(of: " Island", with: ""))
                .font(.subheadline.bold())
                .foregroundStyle(.white)
            Text(island.tagline)
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 108)
        .padding(12)
        .background(
            LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 14)
        )
    }
}

struct IslandDetailView: View {
    @Environment(AppModel.self) private var model
    let island: IslandInfo

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(island.tagline)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.teal)

                Text(island.story)
                    .font(.callout)

                if let lighthouse = island.lighthouse {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionHeader(title: "Lighthouse", icon: "light.beacon.max.fill")
                        Text(lighthouse).font(.callout)
                    }
                    .padding(12)
                    .background(.yellow.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                }

                if !island.activities.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Things to do", icon: "figure.hiking")
                        FlowChips(items: island.activities)
                    }
                }

                if !island.wildlife.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Wildlife", icon: "hare.fill")
                        FlowChips(items: island.wildlife, tint: .green)
                    }
                }

                if !island.funFacts.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionHeader(title: "Fun facts", icon: "sparkles")
                        ForEach(Array(island.funFacts.enumerated()), id: \.offset) { _, fact in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.caption2)
                                    .foregroundStyle(.yellow)
                                    .padding(.top, 3)
                                Text(fact).font(.callout)
                            }
                        }
                    }
                }

                let localPois = model.pois(onIsland: island.name)
                if !localPois.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Landmarks here", icon: "mappin.and.ellipse")
                        ForEach(localPois) { poi in
                            NavigationLink {
                                POIDetailView(poi: poi)
                            } label: {
                                POIRow(poi: poi)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                let localPlaces = model.places(onIsland: island.name)
                if !localPlaces.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        SectionHeader(title: "Stay here", icon: "sailboat.fill")
                        ForEach(localPlaces) { place in
                            NavigationLink {
                                PlaceDetailView(place: place)
                            } label: {
                                PlaceRow(place: place)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(island.sources.enumerated()), id: \.offset) { _, source in
                            Text(source)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 4)
                } label: {
                    Text("Sources").font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationTitle(island.name)
        .navigationBarTitleDisplayMode(.large)
    }
}
