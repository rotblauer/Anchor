import SwiftUI
import AnchorCore

// MARK: - Icons

/// A classic fouled-anchor outline drawn as a stroke path.
struct AnchorIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        let cx = rect.midX
        path.addEllipse(in: CGRect(x: cx - w * 0.11, y: h * 0.03, width: w * 0.22, height: h * 0.18))
        path.move(to: CGPoint(x: cx, y: h * 0.21))
        path.addLine(to: CGPoint(x: cx, y: h * 0.86))
        path.move(to: CGPoint(x: cx - w * 0.26, y: h * 0.33))
        path.addLine(to: CGPoint(x: cx + w * 0.26, y: h * 0.33))
        path.move(to: CGPoint(x: cx - w * 0.38, y: h * 0.60))
        path.addQuadCurve(to: CGPoint(x: cx, y: h * 0.88), control: CGPoint(x: cx - w * 0.38, y: h * 0.90))
        path.move(to: CGPoint(x: cx + w * 0.38, y: h * 0.60))
        path.addQuadCurve(to: CGPoint(x: cx, y: h * 0.88), control: CGPoint(x: cx + w * 0.38, y: h * 0.90))
        return path
    }
}

/// A little pier: deck plus pilings.
struct PierIcon: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width, h = rect.height
        path.move(to: CGPoint(x: w * 0.08, y: h * 0.30))
        path.addLine(to: CGPoint(x: w * 0.92, y: h * 0.30))
        for x in [0.20, 0.50, 0.80] {
            path.move(to: CGPoint(x: w * x, y: h * 0.30))
            path.addLine(to: CGPoint(x: w * x, y: h * 0.85))
        }
        return path
    }
}

struct PlaceTypeIcon: View {
    let type: PlaceType
    var body: some View {
        switch type {
        case .anchorage, .anchorageDock:
            AnchorIcon().stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        case .dock:
            PierIcon().stroke(style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
        case .marina:
            Image(systemName: "fuelpump.fill").resizable().scaledToFit().padding(2)
        }
    }
}

// MARK: - Map markers

struct PlaceMarkerView: View {
    let place: Place
    let band: RatingBand?
    var selected = false

    var body: some View {
        ZStack {
            Circle()
                .fill(place.advisory ? Theme.advisory : Theme.color(for: band))
                .overlay(Circle().strokeBorder(.white, lineWidth: selected ? 3 : 1.8))
            if place.advisory {
                Image(systemName: "exclamationmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                PlaceTypeIcon(type: place.type)
                    .foregroundStyle(.white)
                    .frame(width: 15, height: 15)
            }
        }
        .frame(width: selected ? 34 : 27, height: selected ? 34 : 27)
        .shadow(color: .black.opacity(0.45), radius: 3, y: 1)
        .animation(.spring(duration: 0.25), value: selected)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(.isButton)
    }

    private var accessibilityText: String {
        if place.advisory {
            return "\(place.name), advisory area"
        }
        var text = "\(place.name), \(place.type.label)"
        if let band {
            text += ", \(band.label)"
        }
        return text
    }
}

struct AdvisoryChip: View {
    var compact = false
    var body: some View {
        Label("Advisory", systemImage: "exclamationmark.triangle.fill")
            .font(compact ? .caption2.bold() : .caption.bold())
            .padding(.horizontal, compact ? 6 : 9)
            .padding(.vertical, compact ? 2 : 4)
            .background(Theme.advisory.opacity(0.15), in: Capsule())
            .foregroundStyle(Theme.advisory)
    }
}

/// Wind-field arrow for one grid point: points downwind, colored and sized by speed.
struct WindArrowView: View {
    let sample: WindSample

    var body: some View {
        let length = min(30, 14 + sample.speedKt * 0.7)
        VStack(spacing: 0) {
            WindArrowShape()
                .stroke(style: StrokeStyle(lineWidth: 2.4, lineCap: .round, lineJoin: .round))
                .foregroundStyle(Theme.windColor(kt: sample.speedKt))
                .frame(width: 16, height: length)
                .rotationEffect(.degrees(sample.directionDeg + 180))
                .shadow(color: .black.opacity(0.6), radius: 1.5)
            Text("\(Int(sample.speedKt.rounded()))")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.8), radius: 1.5)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Wind \(Int(sample.speedKt.rounded())) knots from \(Compass.name(forDegrees: sample.directionDeg))")
    }
}

/// Arrow pointing up (toward N before rotation).
struct WindArrowShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cx = rect.midX
        path.move(to: CGPoint(x: cx, y: rect.maxY))
        path.addLine(to: CGPoint(x: cx, y: rect.minY + rect.width * 0.30))
        path.move(to: CGPoint(x: cx - rect.width * 0.30, y: rect.minY + rect.width * 0.55))
        path.addLine(to: CGPoint(x: cx, y: rect.minY))
        path.addLine(to: CGPoint(x: cx + rect.width * 0.30, y: rect.minY + rect.width * 0.55))
        return path
    }
}

// MARK: - Badges & strips

struct BandChip: View {
    let band: RatingBand?
    var compact = false

    var body: some View {
        Text(band?.label ?? "—")
            .font(compact ? .caption2.bold() : .caption.bold())
            .padding(.horizontal, compact ? 6 : 9)
            .padding(.vertical, compact ? 2 : 4)
            .background(Theme.color(for: band).opacity(0.18), in: Capsule())
            .foregroundStyle(Theme.color(for: band))
    }
}

struct StayBadge: View {
    let nights: Int
    var body: some View {
        if nights > 0 {
            Label("\(nights) night\(nights == 1 ? "" : "s")", systemImage: "moon.zzz.fill")
                .font(.caption2.weight(.semibold))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.indigo.opacity(0.15), in: Capsule())
                .foregroundStyle(.indigo)
        }
    }
}

/// The multi-night outlook strip: one square per forecast night.
struct OutlookStrip: View {
    let nights: [NightAssessment]
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 3 : 5) {
            ForEach(nights) { night in
                VStack(spacing: 2) {
                    if !compact {
                        Text(Fmt.weekdayLetter.string(from: night.nightOf))
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                    RoundedRectangle(cornerRadius: compact ? 2.5 : 4)
                        .fill(Theme.color(for: night.band))
                        .frame(width: compact ? 10 : 22, height: compact ? 10 : 22)
                        .overlay {
                            if !compact {
                                Text(Fmt.dayNumber.string(from: night.nightOf))
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Night-by-night outlook")
        .accessibilityValue(
            nights.map { "\(Fmt.nightLabel.string(from: $0.nightOf)) \($0.band.label)" }
                .joined(separator: ", ")
        )
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String
    var body: some View {
        Label(title, systemImage: icon)
            .font(.headline)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct FlowChips: View {
    let items: [String]
    var tint: Color = Theme.teal

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                Text(item)
                    .font(.caption)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(tint.opacity(0.12), in: Capsule())
                    .foregroundStyle(tint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A left-to-right wrapping layout that reports its true wrapped height.
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var usedWidth: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            usedWidth = max(usedWidth, x - spacing)
        }
        return CGSize(width: proposal.width ?? usedWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
