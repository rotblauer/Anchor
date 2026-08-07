import Foundation

/// One hour of modeled open-water waves at a point.
public struct WaveSample: Codable, Hashable, Sendable {
    public let time: Date
    public let heightFt: Double
    public let directionDeg: Double?
    public let periodS: Double?

    public init(time: Date, heightFt: Double, directionDeg: Double?, periodS: Double?) {
        self.time = time
        self.heightFt = heightFt
        self.directionDeg = directionDeg
        self.periodS = periodS
    }
}

/// Client for the free Open-Meteo Marine API, which covers the Great Lakes
/// with a regional wave model. Heights are open-water values — sheltered bays
/// see less — so the app presents them as guidance, not gospel.
public struct OpenMeteoMarineClient: Sendable {
    let session: URLSession
    let maxLocationsPerRequest: Int

    public init(session: URLSession = .shared, maxLocationsPerRequest: Int = 40) {
        self.session = session
        self.maxLocationsPerRequest = maxLocationsPerRequest
    }

    /// Hourly wave forecasts per point, in request order. A point the wave
    /// model can't serve (e.g. on land) yields an empty array, never a shift
    /// in ordering.
    public func hourlyWaves(for points: [GeoPoint], days: Int) async throws -> [[WaveSample]] {
        var results: [[WaveSample]] = []
        results.reserveCapacity(points.count)
        for chunk in points.chunked(into: maxLocationsPerRequest) {
            results.append(contentsOf: try await fetchChunk(chunk, days: days))
        }
        return results
    }

    func fetchChunk(_ points: [GeoPoint], days: Int) async throws -> [[WaveSample]] {
        guard !points.isEmpty else { return [] }
        var components = URLComponents(string: "https://marine-api.open-meteo.com/v1/marine")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: points.map { String(format: "%.4f", $0.lat) }.joined(separator: ",")),
            URLQueryItem(name: "longitude", value: points.map { String(format: "%.4f", $0.lon) }.joined(separator: ",")),
            URLQueryItem(name: "hourly", value: "wave_height,wave_direction,wave_period"),
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "timezone", value: "America/Chicago"),
            URLQueryItem(name: "forecast_days", value: String(days)),
            URLQueryItem(name: "cell_selection", value: "sea"),
        ]
        guard let url = components?.url else { throw OpenMeteoClient.ClientError.badURL }

        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw OpenMeteoClient.ClientError.badResponse(status: http.statusCode)
        }
        return try Self.parse(data: data, points: points)
    }

    static func parse(data: Data, points: [GeoPoint]) throws -> [[WaveSample]] {
        let decoder = JSONDecoder()
        let responses: [OMMarineResponse]
        if let array = try? decoder.decode([OMMarineResponse].self, from: data) {
            responses = array
        } else {
            responses = [try decoder.decode(OMMarineResponse.self, from: data)]
        }
        guard responses.count == points.count else {
            throw OpenMeteoClient.ClientError.mismatchedLocations(expected: points.count, received: responses.count)
        }
        return responses.map(\.waveSamples)
    }
}

struct OMMarineResponse: Decodable {
    let hourly: OMMarineHourly?

    struct OMMarineHourly: Decodable {
        let time: [Double]
        let waveHeight: [Double?]?
        let waveDirection: [Double?]?
        let wavePeriod: [Double?]?

        enum CodingKeys: String, CodingKey {
            case time
            case waveHeight = "wave_height"
            case waveDirection = "wave_direction"
            case wavePeriod = "wave_period"
        }
    }

    /// One sample per hour, gap-filled like the wind decoder so time lookup
    /// stays sound; entirely-missing wave data yields an empty array.
    var waveSamples: [WaveSample] {
        guard let hourly else { return [] }
        let count = hourly.time.count
        let heightsM = OMResponse.gapFilled(hourly.waveHeight ?? [], count: count)
        let directions = OMResponse.gapFilled(hourly.waveDirection ?? [], count: count)
        let periods = OMResponse.gapFilled(hourly.wavePeriod ?? [], count: count)

        var samples: [WaveSample] = []
        samples.reserveCapacity(count)
        for index in 0..<count {
            guard let heightM = heightsM[index] else { continue }
            samples.append(WaveSample(
                time: Date(timeIntervalSince1970: hourly.time[index]),
                heightFt: heightM * 3.28084,
                directionDeg: directions[index],
                periodS: periods[index]
            ))
        }
        return samples
    }
}
