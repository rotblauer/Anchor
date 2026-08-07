import Foundation

/// Utilities for working with 16-sector compass data (N, NNE, NE, … NNW).
/// Shelter and fetch profiles for each place are stored as 16-element arrays
/// whose sector centers sit at 0°, 22.5°, 45°, … 337.5°.
public enum Compass {
    public static let sectorNames = [
        "N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
        "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW",
    ]

    public static let sectorCount = 16
    public static let sectorWidthDeg = 360.0 / 16.0

    public static func normalize(_ degrees: Double) -> Double {
        let d = degrees.truncatingRemainder(dividingBy: 360)
        return d < 0 ? d + 360 : d
    }

    /// Index of the sector whose center is nearest to the given direction.
    public static func sectorIndex(forDegrees degrees: Double) -> Int {
        Int((normalize(degrees) + sectorWidthDeg / 2) / sectorWidthDeg) % sectorCount
    }

    public static func name(forDegrees degrees: Double) -> String {
        sectorNames[sectorIndex(forDegrees: degrees)]
    }

    /// Linear interpolation across a 16-sector array, wrapping at north.
    public static func interpolate(_ values: [Double], atDegrees degrees: Double) -> Double {
        guard values.count == sectorCount else { return values.first ?? 0 }
        let position = normalize(degrees) / sectorWidthDeg
        let lower = Int(position) % sectorCount
        let upper = (lower + 1) % sectorCount
        let fraction = position - position.rounded(.down)
        return values[lower] * (1 - fraction) + values[upper] * fraction
    }

    /// Smallest angle between two bearings, in degrees (0...180).
    public static func angularDifference(_ a: Double, _ b: Double) -> Double {
        let difference = abs(normalize(a) - normalize(b))
        return min(difference, 360 - difference)
    }

    /// Speed-weighted mean direction of a set of (direction, weight) pairs.
    public static func weightedMeanDirection(_ samples: [(directionDeg: Double, weight: Double)]) -> Double {
        var x = 0.0
        var y = 0.0
        for sample in samples {
            let radians = sample.directionDeg * .pi / 180
            x += cos(radians) * sample.weight
            y += sin(radians) * sample.weight
        }
        guard x != 0 || y != 0 else { return 0 }
        return normalize(atan2(y, x) * 180 / .pi)
    }
}
