import Foundation

/// An active NWS marine alert (Small Craft Advisory, Gale Warning, …).
public struct MarineAlert: Identifiable, Hashable, Sendable {
    public let id: String
    public let event: String
    public let headline: String
    public let severity: String
    public let expires: Date?

    public init(id: String, event: String, headline: String, severity: String, expires: Date?) {
        self.id = id
        self.event = event
        self.headline = headline
        self.severity = severity
        self.expires = expires
    }
}

/// Fetches active alerts for NWS marine zones covering Apostle Islands waters
/// from api.weather.gov (which asks for an identifying User-Agent).
public struct MarineAlertsClient: Sendable {
    /// NWS marine zones covering Apostle Islands waters, verified against
    /// api.weather.gov: Chequamegon Bay–Oak Point, Port Wing–Sand Island,
    /// Sand Island–Bayfield, Oak Point–Saxon Harbor, and the outer islands.
    public static let defaultZones = ["LSZ121", "LSZ146", "LSZ147", "LSZ148", "LSZ150"]

    let session: URLSession
    let userAgent: String

    public init(session: URLSession = .shared,
                userAgent: String = "ApostleAnchor/1.0 (iOS; anchoring planner)") {
        self.session = session
        self.userAgent = userAgent
    }

    /// Fetches alerts zone by zone; one zone failing must not discard the
    /// others' alerts. Throws only if every zone fails.
    public func activeAlerts(zones: [String] = MarineAlertsClient.defaultZones) async throws -> [MarineAlert] {
        var collected: [MarineAlert] = []
        var failures = 0
        for zone in zones {
            guard let url = URL(string: "https://api.weather.gov/alerts/active?zone=\(zone)") else {
                failures += 1
                continue
            }
            var request = URLRequest(url: url)
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue("application/geo+json", forHTTPHeaderField: "Accept")
            do {
                let (data, response) = try await session.data(for: request)
                if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                    failures += 1
                    continue
                }
                collected.append(contentsOf: try Self.parse(data: data))
            } catch {
                failures += 1
            }
        }
        if failures == zones.count && !zones.isEmpty {
            throw URLError(.cannotLoadFromNetwork)
        }
        var seen = Set<String>()
        return collected.filter { seen.insert($0.id).inserted }
    }

    static func parse(data: Data) throws -> [MarineAlert] {
        let decoded = try JSONDecoder().decode(AlertsResponse.self, from: data)
        let isoParser = ISO8601DateFormatter()
        return decoded.features.map { feature in
            MarineAlert(
                id: feature.properties.id ?? UUID().uuidString,
                event: feature.properties.event ?? "Marine Alert",
                headline: feature.properties.headline ?? feature.properties.event ?? "Marine Alert",
                severity: feature.properties.severity ?? "Unknown",
                expires: feature.properties.expires.flatMap { isoParser.date(from: $0) }
            )
        }
    }

    struct AlertsResponse: Decodable {
        let features: [Feature]
        struct Feature: Decodable {
            let properties: Properties
        }
        struct Properties: Decodable {
            let id: String?
            let event: String?
            let headline: String?
            let severity: String?
            let expires: String?
        }
    }
}
