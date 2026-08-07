import Foundation

/// One hour of forecast wind (and general weather) at a point.
public struct WindSample: Codable, Hashable, Sendable {
    public let time: Date
    public let speedKt: Double
    public let gustKt: Double
    public let directionDeg: Double
    public let temperatureF: Double?
    public let precipProbability: Double?
    public let weatherCode: Int?

    public init(time: Date, speedKt: Double, gustKt: Double, directionDeg: Double,
                temperatureF: Double? = nil, precipProbability: Double? = nil, weatherCode: Int? = nil) {
        self.time = time
        self.speedKt = speedKt
        self.gustKt = gustKt
        self.directionDeg = directionDeg
        self.temperatureF = temperatureF
        self.precipProbability = precipProbability
        self.weatherCode = weatherCode
    }
}

/// Hourly forecast for one requested point, in request order.
public struct PointForecast: Codable, Sendable {
    public let point: GeoPoint
    public let hours: [WindSample]

    public init(point: GeoPoint, hours: [WindSample]) {
        self.point = point
        self.hours = hours
    }
}

public protocol WeatherProviding: Sendable {
    /// Hourly forecasts for each point, in the same order as `points`.
    func hourlyForecasts(for points: [GeoPoint], days: Int) async throws -> [PointForecast]
}
