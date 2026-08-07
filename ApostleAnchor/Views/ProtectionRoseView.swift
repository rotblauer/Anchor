import SwiftUI
import AnchorCore

/// A 16-sector compass rose showing how protected this spot is from each wind
/// direction (green = sheltered, red = exposed), with an arrow for the
/// currently forecast wind.
struct ProtectionRoseView: View {
    let shelter: [Double]
    var windSample: WindSample?

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let maxRadius = min(size.width, size.height) / 2 - 16

            // Sector wedges
            for index in 0..<min(16, shelter.count) {
                let value = shelter[index]
                let centerAngle = Double(index) * 22.5 - 90
                let start = Angle.degrees(centerAngle - 10.5)
                let end = Angle.degrees(centerAngle + 10.5)
                let radius = maxRadius * (0.35 + 0.65 * value)

                var path = Path()
                path.move(to: center)
                path.addArc(center: center, radius: radius, startAngle: start, endAngle: end, clockwise: false)
                path.closeSubpath()

                // exposed → red hue (0.02), protected → green hue (0.36)
                let color = Color(hue: 0.02 + 0.34 * value, saturation: 0.75, brightness: 0.82)
                context.fill(path, with: .color(color.opacity(0.85)))
            }

            // Ring
            let ring = Path(ellipseIn: CGRect(
                x: center.x - maxRadius, y: center.y - maxRadius,
                width: maxRadius * 2, height: maxRadius * 2))
            context.stroke(ring, with: .color(.secondary.opacity(0.4)), lineWidth: 1)

            // Cardinal labels
            let labels: [(String, Double)] = [("N", 0), ("E", 90), ("S", 180), ("W", 270)]
            for (label, degrees) in labels {
                let radians = (degrees - 90) * .pi / 180
                let position = CGPoint(
                    x: center.x + cos(radians) * (maxRadius + 9),
                    y: center.y + sin(radians) * (maxRadius + 9))
                context.draw(
                    Text(label).font(.system(size: 11, weight: .bold)).foregroundStyle(.secondary),
                    at: position)
            }

            // Forecast wind arrow: drawn from outside the ring pointing inward
            // along the direction the wind blows (wind FROM directionDeg).
            if let sample = windSample {
                let radians = (sample.directionDeg - 90) * .pi / 180
                let outer = CGPoint(
                    x: center.x + cos(radians) * (maxRadius + 4),
                    y: center.y + sin(radians) * (maxRadius + 4))
                let inner = CGPoint(
                    x: center.x + cos(radians) * (maxRadius * 0.45),
                    y: center.y + sin(radians) * (maxRadius * 0.45))

                var arrow = Path()
                arrow.move(to: outer)
                arrow.addLine(to: inner)
                context.stroke(arrow, with: .color(.primary), style: StrokeStyle(lineWidth: 3, lineCap: .round))

                // Arrowhead at the inner end
                let headAngle = atan2(inner.y - outer.y, inner.x - outer.x)
                var head = Path()
                head.move(to: inner)
                head.addLine(to: CGPoint(
                    x: inner.x - cos(headAngle - 0.45) * 10,
                    y: inner.y - sin(headAngle - 0.45) * 10))
                head.move(to: inner)
                head.addLine(to: CGPoint(
                    x: inner.x - cos(headAngle + 0.45) * 10,
                    y: inner.y - sin(headAngle + 0.45) * 10))
                context.stroke(head, with: .color(.primary), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            }
        }
    }
}
