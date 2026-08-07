import Foundation
import CoreLocation

/// A latitude/longitude pair used for forecast requests and grid points.
public struct GeoPoint: Hashable, Codable, Sendable {
    public let lat: Double
    public let lon: Double

    public init(lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

public enum PlaceType: String, Codable, CaseIterable, Sendable {
    case anchorage
    case dock
    case marina
    case anchorageDock = "anchorage_dock"

    public var label: String {
        switch self {
        case .anchorage: return "Anchorage"
        case .dock: return "Dock"
        case .marina: return "Marina"
        case .anchorageDock: return "Anchorage + Dock"
        }
    }
}

public enum Holding: String, Codable, Sendable {
    case good, fair, poor, unknown

    public init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self).lowercased()
        self = Holding(rawValue: raw) ?? .unknown
    }

    public var label: String { rawValue.capitalized }
}

public struct DockInfo: Codable, Hashable, Sendable {
    public var lengthFt: Double?
    public var depthFt: Double?
    public var overnight: Bool?
    public var fee: String?
    public var notes: String?

    public init(lengthFt: Double? = nil, depthFt: Double? = nil, overnight: Bool? = nil,
                fee: String? = nil, notes: String? = nil) {
        self.lengthFt = lengthFt
        self.depthFt = depthFt
        self.overnight = overnight
        self.fee = fee
        self.notes = notes
    }
}

/// A real, documented place to anchor or dock in the Apostle Islands region.
public struct Place: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var island: String
    public var type: PlaceType
    public var lat: Double
    public var lon: Double
    /// 16 values (N…NNW): protection from wind blowing FROM that direction. 1 = fully sheltered.
    public var shelter: [Double]
    /// 16 values (N…NNW): open-water fetch in nautical miles toward that direction.
    public var fetchNm: [Double]
    public var bottom: String
    public var holding: Holding
    public var depthFtMin: Double?
    public var depthFtMax: Double?
    public var dock: DockInfo?
    public var amenities: [String]
    public var description: String
    public var hazards: String?
    public var funFacts: [String]
    public var bestFor: String?
    public var sources: [String]
    /// Informational/hazard entries (wildlife closures, day-stop-only spots)
    /// that must never be recommended as overnight stays.
    public var advisory: Bool

    enum CodingKeys: String, CodingKey {
        case id, name, island, type, lat, lon, shelter, fetchNm, bottom, holding
        case depthFtMin, depthFtMax, dock, amenities, description, hazards
        case funFacts, bestFor, sources, advisory
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        island = try container.decode(String.self, forKey: .island)
        type = try container.decode(PlaceType.self, forKey: .type)
        lat = try container.decode(Double.self, forKey: .lat)
        lon = try container.decode(Double.self, forKey: .lon)
        shelter = try container.decode([Double].self, forKey: .shelter)
        fetchNm = try container.decode([Double].self, forKey: .fetchNm)
        bottom = try container.decodeIfPresent(String.self, forKey: .bottom) ?? "unknown"
        holding = try container.decodeIfPresent(Holding.self, forKey: .holding) ?? .unknown
        depthFtMin = try container.decodeIfPresent(Double.self, forKey: .depthFtMin)
        depthFtMax = try container.decodeIfPresent(Double.self, forKey: .depthFtMax)
        dock = try container.decodeIfPresent(DockInfo.self, forKey: .dock)
        amenities = try container.decodeIfPresent([String].self, forKey: .amenities) ?? []
        description = try container.decode(String.self, forKey: .description)
        hazards = try container.decodeIfPresent(String.self, forKey: .hazards)
        funFacts = try container.decodeIfPresent([String].self, forKey: .funFacts) ?? []
        bestFor = try container.decodeIfPresent(String.self, forKey: .bestFor)
        sources = try container.decodeIfPresent([String].self, forKey: .sources) ?? []
        advisory = try container.decodeIfPresent(Bool.self, forKey: .advisory) ?? false
    }

    public var geo: GeoPoint { GeoPoint(lat: lat, lon: lon) }
    public var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lon) }

    public var canAnchor: Bool { type == .anchorage || type == .anchorageDock }
    public var hasDock: Bool { dock != nil || type == .dock || type == .marina }

    public var depthLabel: String? {
        switch (depthFtMin, depthFtMax) {
        case let (.some(low), .some(high)) where low != high:
            return "\(Int(low))–\(Int(high)) ft"
        case let (.some(low), _):
            return "≈\(Int(low)) ft"
        case let (_, .some(high)):
            return "≈\(Int(high)) ft"
        default:
            return nil
        }
    }
}

public struct PlacesDatabase: Codable, Sendable {
    public let places: [Place]

    public init(places: [Place]) {
        self.places = places
    }

    public static func loadBundled() throws -> PlacesDatabase {
        try load(resource: "places")
    }

    static func load(resource: String) throws -> PlacesDatabase {
        guard let url = Bundle.module.url(forResource: resource, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(PlacesDatabase.self, from: Data(contentsOf: url))
    }
}
