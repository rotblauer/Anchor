import Foundation

/// The grid of points used to draw the wind-field overlay across the archipelago.
public enum WindGrid {
    /// Bounding box that covers the whole Apostle Islands archipelago plus the
    /// approaches: Sand Island in the west to Michigan/Outer in the east,
    /// Chequamegon Point up past Devils Island.
    public static let latMin = 46.72
    public static let latMax = 47.12
    public static let lonMin = -91.08
    public static let lonMax = -90.32

    public static func apostleGrid(rows: Int = 6, cols: Int = 7) -> [GeoPoint] {
        guard rows > 1, cols > 1 else { return [] }
        var points: [GeoPoint] = []
        points.reserveCapacity(rows * cols)
        for row in 0..<rows {
            let lat = latMin + (latMax - latMin) * Double(row) / Double(rows - 1)
            for col in 0..<cols {
                let lon = lonMin + (lonMax - lonMin) * Double(col) / Double(cols - 1)
                points.append(GeoPoint(lat: lat, lon: lon))
            }
        }
        return points
    }

    public static let regionCenter = GeoPoint(lat: 46.93, lon: -90.70)
    public static let regionLatSpan = 0.55
    public static let regionLonSpan = 0.95
}
