import XCTest
@testable import AnchorCore

final class OpenMeteoDecodeTests: XCTestCase {
    let multiLocationFixture = """
    [
      {"latitude": 46.94, "longitude": -90.55,
       "hourly": {"time": [1786000000, 1786003600],
                  "wind_speed_10m": [8.7, 10.1],
                  "wind_direction_10m": [196, 203],
                  "wind_gusts_10m": [14.2, 19.2],
                  "temperature_2m": [61.3, 60.8],
                  "precipitation_probability": [0, 5],
                  "weather_code": [1, 2]}},
      {"latitude": 46.98, "longitude": -90.94,
       "hourly": {"time": [1786000000, 1786003600],
                  "wind_speed_10m": [7.0, null],
                  "wind_direction_10m": [180, 190],
                  "wind_gusts_10m": [null, 12.0],
                  "temperature_2m": null,
                  "precipitation_probability": null,
                  "weather_code": null}}
    ]
    """

    let singleLocationFixture = """
    {"latitude": 46.94, "longitude": -90.55,
     "hourly": {"time": [1786000000],
                "wind_speed_10m": [8.7],
                "wind_direction_10m": [196],
                "wind_gusts_10m": [14.2]}}
    """

    func testParsesMultiLocationArray() throws {
        let points = [GeoPoint(lat: 46.92, lon: -90.55), GeoPoint(lat: 46.98, lon: -90.94)]
        let forecasts = try OpenMeteoClient.parse(data: Data(multiLocationFixture.utf8), points: points)
        XCTAssertEqual(forecasts.count, 2)
        XCTAssertEqual(forecasts[0].point, points[0])
        XCTAssertEqual(forecasts[0].hours.count, 2)
        XCTAssertEqual(forecasts[0].hours[0].speedKt, 8.7, accuracy: 1e-9)
        XCTAssertEqual(forecasts[0].hours[0].gustKt, 14.2, accuracy: 1e-9)
        XCTAssertEqual(forecasts[0].hours[0].time, Date(timeIntervalSince1970: 1786000000))

        // Second location: null values are gap-filled, never dropped — index
        // alignment against the shared hour axis must be preserved.
        XCTAssertEqual(forecasts[1].hours.count, 2)
        XCTAssertEqual(forecasts[1].hours[1].speedKt, 7.0, accuracy: 1e-9, "null speed carries forward")
        XCTAssertEqual(forecasts[1].hours[0].gustKt, 12.0, accuracy: 1e-9, "leading null gust backfills")
        XCTAssertEqual(forecasts[1].hours[1].time, Date(timeIntervalSince1970: 1786003600))
        XCTAssertNil(forecasts[1].hours[0].temperatureF)
    }

    func testGapFilling() {
        XCTAssertEqual(OMResponse.gapFilled([nil, 2, nil, nil, 5], count: 5), [2, 2, 2, 2, 5] as [Double?])
        XCTAssertEqual(OMResponse.gapFilled([1, nil], count: 2), [1, 1] as [Double?])
        XCTAssertEqual(OMResponse.gapFilled(nil, count: 3), [Double?](repeating: nil, count: 3))
        XCTAssertEqual(OMResponse.gapFilled([nil, nil], count: 2), [Double?](repeating: nil, count: 2))
    }

    func testParsesSingleLocationObject() throws {
        let points = [GeoPoint(lat: 46.92, lon: -90.55)]
        let forecasts = try OpenMeteoClient.parse(data: Data(singleLocationFixture.utf8), points: points)
        XCTAssertEqual(forecasts.count, 1)
        XCTAssertEqual(forecasts[0].hours.count, 1)
    }

    func testMismatchedCountThrows() {
        let points = [GeoPoint(lat: 46.92, lon: -90.55)]
        XCTAssertThrowsError(try OpenMeteoClient.parse(data: Data(multiLocationFixture.utf8), points: points))
    }

    func testChunking() {
        let items = Array(1...95)
        let chunks = items.chunked(into: 40)
        XCTAssertEqual(chunks.map(\.count), [40, 40, 15])
    }
}
