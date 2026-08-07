import XCTest
@testable import AnchorCore

final class MarineDecodeTests: XCTestCase {
    let fixture = """
    [
      {"latitude": 46.95, "longitude": -90.55,
       "hourly": {"time": [1786000000, 1786003600],
                  "wave_height": [0.5, null],
                  "wave_direction": [200, 210],
                  "wave_period": [3.2, 3.4]}},
      {"latitude": 46.90, "longitude": -90.80,
       "hourly": {"time": [1786000000, 1786003600],
                  "wave_height": null,
                  "wave_direction": null,
                  "wave_period": null}}
    ]
    """

    func testParsesWavesWithGapFillAndMetersToFeet() throws {
        let points = [GeoPoint(lat: 46.95, lon: -90.55), GeoPoint(lat: 46.90, lon: -90.80)]
        let waves = try OpenMeteoMarineClient.parse(data: Data(fixture.utf8), points: points)
        XCTAssertEqual(waves.count, 2)

        XCTAssertEqual(waves[0].count, 2)
        XCTAssertEqual(waves[0][0].heightFt, 0.5 * 3.28084, accuracy: 1e-6)
        XCTAssertEqual(waves[0][1].heightFt, 0.5 * 3.28084, accuracy: 1e-6, "null height carries forward")
        XCTAssertEqual(waves[0][1].directionDeg ?? -1, 210, accuracy: 1e-9)

        XCTAssertTrue(waves[1].isEmpty, "a point with no wave data yields an empty array, not a shifted one")
    }

    func testMismatchedCountThrows() {
        XCTAssertThrowsError(try OpenMeteoMarineClient.parse(
            data: Data(fixture.utf8), points: [GeoPoint(lat: 46.95, lon: -90.55)]))
    }

    func testPlaceTypeFilter() throws {
        func place(type: String) -> Place {
            let json = """
            {"id": "x", "name": "X", "island": "Y", "type": "\(type)", "lat": 46.9, "lon": -90.6,
             "shelter": [\(Array(repeating: "0.5", count: 16).joined(separator: ","))],
             "fetchNm": [\(Array(repeating: "1", count: 16).joined(separator: ","))],
             "description": "d", "sources": ["s"]}
            """
            return try! JSONDecoder().decode(Place.self, from: Data(json.utf8))
        }

        let anchoragesOnly = PlaceTypeFilter(includeAnchorages: true, includeDocks: false, includeMarinas: false)
        XCTAssertTrue(anchoragesOnly.matches(place(type: "anchorage")))
        XCTAssertTrue(anchoragesOnly.matches(place(type: "anchorage_dock")), "combined spots still allow anchoring")
        XCTAssertFalse(anchoragesOnly.matches(place(type: "dock")))
        XCTAssertFalse(anchoragesOnly.matches(place(type: "marina")))

        let noMarinas = PlaceTypeFilter(includeAnchorages: true, includeDocks: true, includeMarinas: false)
        XCTAssertFalse(noMarinas.matches(place(type: "marina")))
        XCTAssertTrue(noMarinas.matches(place(type: "dock")))

        let none = PlaceTypeFilter(includeAnchorages: false, includeDocks: false, includeMarinas: false)
        XCTAssertFalse(none.matches(place(type: "anchorage")))
    }
}
