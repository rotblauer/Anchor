import Foundation

/// Client for the free Open-Meteo forecast API (no key required).
///
/// Multi-location batching: comma-separated latitude/longitude lists return a
/// JSON array of per-location responses in request order. We request unixtime
/// stamps and knots so decoding is timezone-proof.
public struct OpenMeteoClient: WeatherProviding {
    public enum ClientError: Error, LocalizedError {
        case badURL
        case badResponse(status: Int)
        case mismatchedLocations(expected: Int, received: Int)

        public var errorDescription: String? {
            switch self {
            case .badURL: return "Could not build the forecast request."
            case .badResponse(let status): return "Forecast service returned status \(status)."
            case .mismatchedLocations: return "Forecast service returned unexpected data."
            }
        }
    }

    let session: URLSession
    let maxLocationsPerRequest: Int

    public init(session: URLSession = .shared, maxLocationsPerRequest: Int = 40) {
        self.session = session
        self.maxLocationsPerRequest = maxLocationsPerRequest
    }

    public func hourlyForecasts(for points: [GeoPoint], days: Int) async throws -> [PointForecast] {
        var results: [PointForecast] = []
        results.reserveCapacity(points.count)
        for chunk in points.chunked(into: maxLocationsPerRequest) {
            results.append(contentsOf: try await fetchChunk(chunk, days: days))
        }
        return results
    }

    func fetchChunk(_ points: [GeoPoint], days: Int) async throws -> [PointForecast] {
        guard !points.isEmpty else { return [] }
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: points.map { String(format: "%.4f", $0.lat) }.joined(separator: ",")),
            URLQueryItem(name: "longitude", value: points.map { String(format: "%.4f", $0.lon) }.joined(separator: ",")),
            URLQueryItem(name: "hourly", value: "wind_speed_10m,wind_direction_10m,wind_gusts_10m,temperature_2m,precipitation_probability,weather_code"),
            URLQueryItem(name: "wind_speed_unit", value: "kn"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "timezone", value: "America/Chicago"),
            URLQueryItem(name: "forecast_days", value: String(days)),
        ]
        guard let url = components?.url else { throw ClientError.badURL }

        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw ClientError.badResponse(status: http.statusCode)
        }
        return try Self.parse(data: data, points: points)
    }

    static func parse(data: Data, points: [GeoPoint]) throws -> [PointForecast] {
        let decoder = JSONDecoder()
        let responses: [OMResponse]
        if let array = try? decoder.decode([OMResponse].self, from: data) {
            responses = array
        } else {
            responses = [try decoder.decode(OMResponse.self, from: data)]
        }
        guard responses.count == points.count else {
            throw ClientError.mismatchedLocations(expected: points.count, received: responses.count)
        }
        return zip(points, responses).map { point, response in
            PointForecast(point: point, hours: response.windSamples)
        }
    }
}

// MARK: - Response decoding

struct OMResponse: Decodable {
    let latitude: Double
    let longitude: Double
    let hourly: OMHourly

    /// One sample per entry of `hourly.time`, always. The app indexes samples
    /// positionally against a shared hour axis, so a null wind value must be
    /// gap-filled from neighboring hours — never dropped, which would silently
    /// shift every later hour's data.
    var windSamples: [WindSample] {
        let count = hourly.time.count
        let speeds = Self.gapFilled(hourly.windSpeed10M, count: count)
        let directions = Self.gapFilled(hourly.windDirection10M, count: count)
        let gusts = Self.gapFilled(hourly.windGusts10M, count: count)

        var samples: [WindSample] = []
        samples.reserveCapacity(count)
        for index in 0..<count {
            // Still nil only when the entire array is missing — then the whole
            // location is unusable and we return no samples for it.
            guard let speed = speeds[index], let direction = directions[index] else { continue }
            let gust = gusts[index] ?? speed * 1.25
            samples.append(WindSample(
                time: Date(timeIntervalSince1970: hourly.time[index]),
                speedKt: speed,
                gustKt: max(gust, speed),
                directionDeg: direction,
                temperatureF: hourly.temperature2M?[safeIndex: index] ?? nil,
                precipProbability: hourly.precipitationProbability?[safeIndex: index] ?? nil,
                weatherCode: hourly.weatherCode?[safeIndex: index] ?? nil
            ))
        }
        return samples
    }

    /// Fills interior/leading/trailing nils by carrying the nearest valid value
    /// (forward first, then backward for leading gaps).
    static func gapFilled(_ values: [Double?]?, count: Int) -> [Double?] {
        var result = [Double?](repeating: nil, count: count)
        if let values {
            for index in 0..<Swift.min(count, values.count) { result[index] = values[index] }
        }
        var carried: Double?
        for index in 0..<count {
            if let value = result[index] { carried = value } else { result[index] = carried }
        }
        carried = nil
        for index in stride(from: count - 1, through: 0, by: -1) {
            if let value = result[index] { carried = value } else { result[index] = carried }
        }
        return result
    }
}

struct OMHourly: Decodable {
    let time: [Double]
    let windSpeed10M: [Double?]
    let windDirection10M: [Double?]
    let windGusts10M: [Double?]?
    let temperature2M: [Double?]?
    let precipitationProbability: [Double?]?
    let weatherCode: [Int?]?

    enum CodingKeys: String, CodingKey {
        case time
        case windSpeed10M = "wind_speed_10m"
        case windDirection10M = "wind_direction_10m"
        case windGusts10M = "wind_gusts_10m"
        case temperature2M = "temperature_2m"
        case precipitationProbability = "precipitation_probability"
        case weatherCode = "weather_code"
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }

    subscript(safeIndex index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
