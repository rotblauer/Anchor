import XCTest
@testable import AnchorCore

/// Structural validation of the bundled databases. These tests are the
/// guard-rail against fabricated or malformed place data: every place must
/// carry sources, well-formed 16-sector profiles, and coordinates inside the
/// Apostle Islands region.
final class DatabaseTests: XCTestCase {
    func testPlacesDatabaseLoadsAndIsValid() throws {
        let db = try PlacesDatabase.loadBundled()
        XCTAssertGreaterThanOrEqual(db.places.count, 3)

        var seenIds = Set<String>()
        for place in db.places {
            XCTAssertTrue(seenIds.insert(place.id).inserted, "duplicate id \(place.id)")
            XCTAssertFalse(place.name.isEmpty)
            XCTAssertFalse(place.island.isEmpty)
            XCTAssertFalse(place.description.isEmpty, "\(place.id) needs a description")
            XCTAssertFalse(place.sources.isEmpty, "\(place.id) must cite at least one source")

            XCTAssertEqual(place.shelter.count, 16, "\(place.id) shelter must have 16 sectors")
            XCTAssertEqual(place.fetchNm.count, 16, "\(place.id) fetch must have 16 sectors")
            for value in place.shelter {
                XCTAssertTrue((0...1).contains(value), "\(place.id) shelter out of range")
            }
            for value in place.fetchNm {
                XCTAssertTrue((0...300).contains(value), "\(place.id) fetch out of range")
            }

            XCTAssertTrue((46.5...47.3).contains(place.lat), "\(place.id) latitude \(place.lat) outside region")
            XCTAssertTrue((-91.4...(-90.1)).contains(place.lon), "\(place.id) longitude \(place.lon) outside region")

            if let low = place.depthFtMin, let high = place.depthFtMax {
                XCTAssertLessThanOrEqual(low, high, "\(place.id) depth range inverted")
            }
        }
    }

    func testPOIDatabaseLoadsAndIsValid() throws {
        let db = try POIDatabase.loadBundled()
        XCTAssertGreaterThanOrEqual(db.pois.count, 3)
        var seenIds = Set<String>()
        for poi in db.pois {
            XCTAssertTrue(seenIds.insert(poi.id).inserted, "duplicate POI id \(poi.id)")
            XCTAssertFalse(poi.story.isEmpty, "\(poi.id) needs a story")
            XCTAssertFalse(poi.tagline.isEmpty, "\(poi.id) needs a tagline")
            XCTAssertFalse(poi.sources.isEmpty, "\(poi.id) must cite at least one source")
            XCTAssertTrue((46.4...47.3).contains(poi.lat), "\(poi.id) latitude \(poi.lat) outside region")
            XCTAssertTrue((-91.4...(-90.1)).contains(poi.lon), "\(poi.id) longitude \(poi.lon) outside region")
        }
    }

    func testContentDatabaseLoads() throws {
        let content = try ContentDatabase.loadBundled()
        XCTAssertGreaterThanOrEqual(content.islands.count, 2)
        XCTAssertFalse(content.park.overview.isEmpty)
        for island in content.islands {
            XCTAssertFalse(island.story.isEmpty, "\(island.name) needs a story")
            XCTAssertFalse(island.sources.isEmpty, "\(island.name) must cite sources")
        }
    }
}
