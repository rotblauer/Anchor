import SwiftUI
import MapKit
import AnchorCore

struct PlaceDetailView: View {
    @Environment(AppModel.self) private var model
    let place: Place

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                if place.advisory {
                    advisoryBanner
                } else if let night = model.selectedNight(for: place.id) {
                    outlookSection
                    whySection(night)
                }
                windChartSection
                roseSection
                factsSection
                if let dock = place.dock {
                    dockSection(dock)
                }
                if let hazards = place.hazards, !hazards.isEmpty {
                    hazardsSection(hazards)
                }
                if !place.funFacts.isEmpty {
                    funFactsSection
                }
                actionsSection
                sourcesSection
            }
            .padding()
        }
        .navigationTitle(place.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(place.name).font(.title2.bold())
                    Text("\(place.island) · \(place.type.label)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    if place.advisory {
                        AdvisoryChip()
                    } else {
                        BandChip(band: model.selectedNight(for: place.id)?.band)
                        if let night = model.selectedNightDate {
                            Text("night of \(Fmt.nightLabel.string(from: night))")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            if let bestFor = place.bestFor {
                Label(bestFor, systemImage: "star.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.teal)
            }
            Text(place.description)
                .font(.callout)
        }
    }

    private var advisoryBanner: some View {
        Label("Not a place to stay — closure or hazard information only. Read the details below before transiting this area.", systemImage: "exclamationmark.triangle.fill")
            .font(.callout.weight(.medium))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.advisory.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            .foregroundStyle(Theme.advisory)
    }

    private var outlookSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Night-by-night outlook", icon: "calendar")
            if let outlook = model.outlooks[place.id] {
                OutlookStrip(nights: outlook.nights)
                if let nightDate = model.selectedNightDate,
                   let index = outlook.nightIndex(of: nightDate, calendar: model.calendar) {
                    let streak = outlook.consecutiveGoodNights(from: index)
                    if streak > 1 {
                        Text("Good for \(streak) consecutive nights from here.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if streak == 1 {
                        Text("Works for this night; conditions change after.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func whySection(_ night: NightAssessment) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Why this rating", icon: "questionmark.circle")
            ForEach(Array(night.reasons.enumerated()), id: \.offset) { _, reason in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(Theme.color(for: night.band)).frame(width: 6, height: 6)
                        .padding(.top, 6)
                    Text(reason).font(.callout)
                }
            }
        }
        .padding(12)
        .background(Theme.color(for: night.band).opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var windChartSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Wind forecast here", icon: "wind")
            if let samples = model.samplesByPlace[place.id], !samples.isEmpty {
                WindChartView(samples: samples)
            } else {
                Text("Fetch the forecast to see wind for this spot.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var roseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Shelter by wind direction", icon: "safari")
            HStack(alignment: .center, spacing: 16) {
                ProtectionRoseView(
                    shelter: place.shelter,
                    windSample: model.sample(for: place.id)
                )
                .frame(width: 170, height: 170)
                VStack(alignment: .leading, spacing: 6) {
                    Label("Green = protected wind directions", systemImage: "shield.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                    Label("Red = exposed directions", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                    if let sample = model.sample(for: place.id) {
                        Label("\(Fmt.hourLabel.string(from: sample.time)): \(Fmt.windSummary(sample))",
                              systemImage: "location.north.line")
                            .font(.caption.bold())
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }

    private var factsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "The details", icon: "ruler")
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                if let depth = place.depthLabel {
                    factRow("Depth", depth)
                }
                factRow("Bottom", place.bottom.capitalized)
                if place.canAnchor {
                    factRow("Holding", place.holding.label)
                }
                factRow("Position", String(format: "%.4f, %.4f", place.lat, place.lon))
            }
            if !place.amenities.isEmpty {
                FlowChips(items: place.amenities)
            }
        }
    }

    private func factRow(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.callout.weight(.medium))
        }
    }

    private func dockSection(_ dock: DockInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Dock", icon: "point.topleft.down.to.point.bottomright.curvepath")
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                if let length = dock.lengthFt {
                    factRow("Length", "\(Int(length)) ft")
                }
                if let depth = dock.depthFt {
                    factRow("Depth alongside", "\(Int(depth)) ft")
                }
                if let overnight = dock.overnight {
                    factRow("Overnight", overnight ? "Allowed" : "Day use only")
                }
                if let fee = dock.fee, !fee.isEmpty {
                    factRow("Fee", fee)
                }
            }
            if let notes = dock.notes, !notes.isEmpty {
                Text(notes).font(.callout)
            }
        }
        .padding(12)
        .background(Theme.teal.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private func hazardsSection(_ hazards: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Watch out for", icon: "exclamationmark.triangle.fill")
            Text(hazards).font(.callout)
        }
        .padding(12)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
    }

    private var funFactsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionHeader(title: "Good to know", icon: "sparkles")
            ForEach(Array(place.funFacts.enumerated()), id: \.offset) { _, fact in
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

    private var actionsSection: some View {
        Button {
            let item = MKMapItem(placemark: MKPlacemark(coordinate: place.coordinate))
            item.name = place.name
            item.openInMaps()
        } label: {
            Label("Open in Maps", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(Theme.teal)
    }

    private var sourcesSection: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(place.sources.enumerated()), id: \.offset) { _, source in
                    Text(source)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        } label: {
            Text("Sources")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
