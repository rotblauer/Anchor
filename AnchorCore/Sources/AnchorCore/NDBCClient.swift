import Foundation

/// A fixed NDBC / GLOS observing station near the Apostle Islands.
public struct BuoyStation: Hashable, Sendable {
    public let id: String
    public let name: String
    public let lat: Double
    public let lon: Double

    public init(id: String, name: String, lat: Double, lon: Double) {
        self.id = id
        self.name = name
        self.lat = lat
        self.lon = lon
    }
}

/// The latest real observation from a station — the "right now" reality
/// check against the forecast.
public struct BuoyObservation: Codable, Hashable, Identifiable, Sendable {
    public var id: String { stationId }
    public let stationId: String
    public let stationName: String
    public let lat: Double
    public let lon: Double
    public let time: Date
    public let windDirDeg: Double?
    public let windKt: Double?
    public let gustKt: Double?
    public let waveHtFt: Double?
    public let airTempF: Double?
    public let waterTempF: Double?

    public init(stationId: String, stationName: String, lat: Double, lon: Double, time: Date,
                windDirDeg: Double?, windKt: Double?, gustKt: Double?, waveHtFt: Double?,
                airTempF: Double?, waterTempF: Double?) {
        self.stationId = stationId
        self.stationName = stationName
        self.lat = lat
        self.lon = lon
        self.time = time
        self.windDirDeg = windDirDeg
        self.windKt = windKt
        self.gustKt = gustKt
        self.waveHtFt = waveHtFt
        self.airTempF = airTempF
        self.waterTempF = waterTempF
    }

    public var ageMinutes: Int {
        Int(Date().timeIntervalSince(time) / 60)
    }
}

/// Fetches latest observations from NDBC's realtime2 text feeds.
/// Stations come and go (Devils Island's C-MAN has a history of outages), so
/// a station that 404s or reports nothing simply drops out of the result.
public struct NDBCClient: Sendable {
    /// Verified stations around the archipelago: Devils Island (the classic
    /// in-archipelago C-MAN, currently intermittent), Port Wing (western
    /// approach), Saxon Harbor (eastern side).
    public static let apostleStations = [
        BuoyStation(id: "DISW3", name: "Devils Island", lat: 47.079, lon: -90.728),
        BuoyStation(id: "PNGW3", name: "Port Wing", lat: 46.792, lon: -91.386),
        BuoyStation(id: "SXHW3", name: "Saxon Harbor", lat: 46.563, lon: -90.437),
    ]

    let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Latest observation per reachable station; unreachable stations are omitted.
    public func latestObservations(stations: [BuoyStation] = NDBCClient.apostleStations) async -> [BuoyObservation] {
        var results: [BuoyObservation] = []
        for station in stations {
            guard let url = URL(string: "https://www.ndbc.noaa.gov/data/realtime2/\(station.id).txt") else { continue }
            guard let (data, response) = try? await session.data(from: url),
                  let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  let text = String(data: data, encoding: .utf8) else { continue }
            if let observation = Self.parse(text: text, station: station) {
                results.append(observation)
            }
        }
        return results
    }

    /// Parses the realtime2 fixed-column text format. The header line names
    /// the columns, so this survives stations that omit trailing fields.
    static func parse(text: String, station: BuoyStation) -> BuoyObservation? {
        let lines = text.split(separator: "\n").map(String.init)
        guard let headerLine = lines.first(where: { $0.hasPrefix("#YY") }) else { return nil }
        let columns = headerLine.dropFirst().split(separator: " ").map(String.init)

        for line in lines where !line.hasPrefix("#") {
            let values = line.split(separator: " ").map(String.init)
            guard values.count >= 5 else { continue }
            var fields: [String: String] = [:]
            for (name, value) in zip(columns, values) { fields[name] = value }

            func number(_ key: String) -> Double? {
                guard let raw = fields[key], raw != "MM" else { return nil }
                return Double(raw)
            }

            guard let year = number("YY"), let month = number("MM"),
                  let day = number("DD"), let hour = number("hh"), let minute = number("mm") else { continue }
            var components = DateComponents()
            components.year = Int(year)
            components.month = Int(month)
            components.day = Int(day)
            components.hour = Int(hour)
            components.minute = Int(minute)
            components.timeZone = TimeZone(identifier: "UTC")
            guard let time = Calendar(identifier: .gregorian).date(from: components) else { continue }

            let windMs = number("WSPD")
            let gustMs = number("GST")
            let waveM = number("WVHT")
            let airC = number("ATMP")
            let waterC = number("WTMP")

            // Require at least wind to be useful as a reality check.
            guard windMs != nil || waveM != nil else { continue }

            return BuoyObservation(
                stationId: station.id,
                stationName: station.name,
                lat: station.lat,
                lon: station.lon,
                time: time,
                windDirDeg: number("WDIR"),
                windKt: windMs.map { $0 * 1.94384 },
                gustKt: gustMs.map { $0 * 1.94384 },
                waveHtFt: waveM.map { $0 * 3.28084 },
                airTempF: airC.map { $0 * 9 / 5 + 32 },
                waterTempF: waterC.map { $0 * 9 / 5 + 32 }
            )
        }
        return nil
    }
}
