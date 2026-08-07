import SwiftUI
import MapKit
import AnchorCore

extension POIKind {
    var color: Color {
        switch self {
        case .lighthouse: return Color(red: 0.85, green: 0.65, blue: 0.13)
        case .shipwreck: return Color(red: 0.63, green: 0.32, blue: 0.18)
        case .seaCave: return Color(red: 0.15, green: 0.55, blue: 0.75)
        case .historic: return Color(red: 0.55, green: 0.38, blue: 0.65)
        case .natural: return Color(red: 0.22, green: 0.60, blue: 0.35)
        }
    }

    var symbol: String {
        switch self {
        case .lighthouse: return "light.beacon.max.fill"
        case .shipwreck: return "water.waves.and.arrow.down"
        case .seaCave: return "water.waves"
        case .historic: return "building.columns.fill"
        case .natural: return "leaf.fill"
        }
    }
}

/// Map marker for a point of interest — a rounded diamond so lore pins read
/// differently from the circular places-to-stay pins.
struct POIMarkerView: View {
    let poi: PointOfInterest
    var selected = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(poi.kind.color)
                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.white, lineWidth: selected ? 2.5 : 1.5))
                .rotationEffect(.degrees(45))
            Image(systemName: poi.kind.symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
        }
        .frame(width: selected ? 28 : 22, height: selected ? 28 : 22)
        .shadow(color: .black.opacity(0.45), radius: 2.5, y: 1)
        .animation(.spring(duration: 0.25), value: selected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(poi.name), \(poi.kind.label)")
        .accessibilityAddTraits(.isButton)
    }
}

struct POIKindChip: View {
    let kind: POIKind
    var body: some View {
        Label(kind.label, systemImage: kind.symbol)
            .font(.caption.bold())
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(kind.color.opacity(0.15), in: Capsule())
            .foregroundStyle(kind.color)
    }
}

struct POIDetailView: View {
    let poi: PointOfInterest

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(poi.name).font(.title2.bold())
                            Text(poi.island).font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        POIKindChip(kind: poi.kind)
                    }
                    Text(poi.tagline)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(poi.kind.color)
                }

                ForEach(Array(poi.story.components(separatedBy: "\n\n").enumerated()), id: \.offset) { _, paragraph in
                    Text(paragraph).font(.callout)
                }

                if let tips = poi.visitTips {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionHeader(title: "Visiting", icon: "figure.walk")
                        Text(tips).font(.callout)
                    }
                    .padding(12)
                    .background(poi.kind.color.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                }

                if !poi.funFacts.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        SectionHeader(title: "Fun facts", icon: "sparkles")
                        ForEach(Array(poi.funFacts.enumerated()), id: \.offset) { _, fact in
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

                Button {
                    let item = MKMapItem(placemark: MKPlacemark(coordinate: poi.coordinate))
                    item.name = poi.name
                    item.openInMaps()
                } label: {
                    Label("Open in Maps", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(poi.kind.color)

                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(poi.sources.enumerated()), id: \.offset) { _, source in
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
        .navigationTitle(poi.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Compact row used in Explore and island pages.
struct POIRow: View {
    let poi: PointOfInterest

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(poi.kind.color.opacity(0.16))
                Image(systemName: poi.kind.symbol)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(poi.kind.color)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 2) {
                Text(poi.name).font(.subheadline.weight(.medium))
                Text(poi.tagline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
    }
}
