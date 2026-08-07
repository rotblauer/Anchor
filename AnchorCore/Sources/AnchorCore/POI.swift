import Foundation
import CoreLocation

/// Categories of point-of-interest — the lore layer of the app.
public enum POIKind: String, Codable, CaseIterable, Sendable {
    case lighthouse
    case shipwreck
    case seaCave = "sea_cave"
    case historic
    case natural

    public var label: String {
        switch self {
        case .lighthouse: return "Lighthouse"
        case .shipwreck: return "Shipwreck"
        case .seaCave: return "Sea Caves"
        case .historic: return "Historic Site"
        case .natural: return "Natural Wonder"
        }
    }
}

/// A real, documented point of interest: a lighthouse, wreck, sea-cave area,
/// historic site, or natural wonder. Never part of stay recommendations.
public struct PointOfInterest: Codable, Identifiable, Hashable, Sendable {
    public let id: String
    public var name: String
    public var island: String
    public var kind: POIKind
    public var lat: Double
    public var lon: Double
    public var tagline: String
    public var story: String
    public var funFacts: [String]
    public var visitTips: String?
    public var sources: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, island, kind, lat, lon, tagline, story, funFacts, visitTips, sources
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        island = try container.decode(String.self, forKey: .island)
        kind = try container.decode(POIKind.self, forKey: .kind)
        lat = try container.decode(Double.self, forKey: .lat)
        lon = try container.decode(Double.self, forKey: .lon)
        tagline = try container.decode(String.self, forKey: .tagline)
        story = try container.decode(String.self, forKey: .story)
        funFacts = try container.decodeIfPresent([String].self, forKey: .funFacts) ?? []
        let tips = try container.decodeIfPresent(String.self, forKey: .visitTips) ?? ""
        visitTips = tips.isEmpty ? nil : tips
        sources = try container.decodeIfPresent([String].self, forKey: .sources) ?? []
    }

    public var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }
}

public struct POIDatabase: Codable, Sendable {
    public let pois: [PointOfInterest]

    public static func loadBundled() throws -> POIDatabase {
        guard let url = Bundle.module.url(forResource: "pois", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(POIDatabase.self, from: Data(contentsOf: url))
    }
}
