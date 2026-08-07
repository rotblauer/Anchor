import Foundation

/// Visitor-facing content about an island (or the mainland) for the Explore tab.
public struct IslandInfo: Codable, Identifiable, Hashable, Sendable {
    public var id: String { name }
    public var name: String
    public var tagline: String
    public var story: String
    public var lighthouse: String?
    public var activities: [String]
    public var wildlife: [String]
    public var funFacts: [String]
    public var sources: [String]

    enum CodingKeys: String, CodingKey {
        case name, tagline, story, lighthouse, activities, wildlife, funFacts, sources
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        tagline = try container.decode(String.self, forKey: .tagline)
        story = try container.decode(String.self, forKey: .story)
        let lighthouseText = try container.decodeIfPresent(String.self, forKey: .lighthouse) ?? ""
        lighthouse = lighthouseText.isEmpty ? nil : lighthouseText
        activities = try container.decodeIfPresent([String].self, forKey: .activities) ?? []
        wildlife = try container.decodeIfPresent([String].self, forKey: .wildlife) ?? []
        funFacts = try container.decodeIfPresent([String].self, forKey: .funFacts) ?? []
        sources = try container.decodeIfPresent([String].self, forKey: .sources) ?? []
    }
}

public struct ParkInfo: Codable, Hashable, Sendable {
    public var overview: String
    public var seaCaves: String
    public var camping: String?
    public var boatingSafety: String
    public var sources: [String]

    enum CodingKeys: String, CodingKey {
        case overview, seaCaves, camping, boatingSafety, sources
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        overview = try container.decode(String.self, forKey: .overview)
        seaCaves = try container.decode(String.self, forKey: .seaCaves)
        camping = try container.decodeIfPresent(String.self, forKey: .camping)
        boatingSafety = try container.decode(String.self, forKey: .boatingSafety)
        sources = try container.decodeIfPresent([String].self, forKey: .sources) ?? []
    }
}

public struct ContentDatabase: Codable, Sendable {
    public let islands: [IslandInfo]
    public let park: ParkInfo

    public static func loadBundled() throws -> ContentDatabase {
        guard let url = Bundle.module.url(forResource: "islands", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try JSONDecoder().decode(ContentDatabase.self, from: Data(contentsOf: url))
    }

    public func island(named name: String) -> IslandInfo? {
        islands.first { name.localizedCaseInsensitiveContains($0.name) || $0.name.localizedCaseInsensitiveContains(name) }
    }
}
