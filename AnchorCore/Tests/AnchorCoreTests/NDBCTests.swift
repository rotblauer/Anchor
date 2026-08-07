import XCTest
@testable import AnchorCore

final class NDBCTests: XCTestCase {
    let station = BuoyStation(id: "SXHW3", name: "Saxon Harbor", lat: 46.563, lon: -90.437)

    let fixture = """
    #YY  MM DD hh mm WDIR WSPD GST  WVHT   DPD   APD MWD   PRES  ATMP  WTMP  DEWP  VIS PTDY  TIDE
    #yr  mo dy hr mn degT m/s  m/s     m   sec   sec degT   hPa  degC  degC  degC  nmi  hPa    ft
    2026 08 07 13 50 220  1.5  5.1    MM    MM    MM  MM 1012.9  23.5    MM    MM   MM   MM    MM
    2026 08 07 13 40 220  1.5  3.6    MM    MM    MM  MM 1012.9  23.2    MM    MM   MM   MM    MM
    """

    func testParsesLatestObservation() throws {
        let observation = try XCTUnwrap(NDBCClient.parse(text: fixture, station: station))
        XCTAssertEqual(observation.stationId, "SXHW3")
        XCTAssertEqual(observation.windDirDeg ?? -1, 220, accuracy: 1e-9)
        XCTAssertEqual(observation.windKt ?? -1, 1.5 * 1.94384, accuracy: 1e-6)
        XCTAssertEqual(observation.gustKt ?? -1, 5.1 * 1.94384, accuracy: 1e-6)
        XCTAssertNil(observation.waveHtFt, "MM wave height must be nil")
        XCTAssertEqual(observation.airTempF ?? -1, 23.5 * 9 / 5 + 32, accuracy: 1e-6)

        var components = DateComponents()
        components.year = 2026; components.month = 8; components.day = 7
        components.hour = 13; components.minute = 50
        components.timeZone = TimeZone(identifier: "UTC")
        XCTAssertEqual(observation.time, Calendar(identifier: .gregorian).date(from: components))
    }

    func testSkipsAllMissingLinesAndFindsUsableOne() throws {
        let sparse = """
        #YY  MM DD hh mm WDIR WSPD GST  WVHT
        #yr  mo dy hr mn degT m/s  m/s     m
        2026 08 07 13 50  MM   MM  MM    MM
        2026 08 07 13 40 270  4.6  5.7    MM
        """
        let observation = try XCTUnwrap(NDBCClient.parse(text: sparse, station: station))
        XCTAssertEqual(observation.windDirDeg ?? -1, 270, accuracy: 1e-9)
    }

    func testGarbageReturnsNil() {
        XCTAssertNil(NDBCClient.parse(text: "<html>404</html>", station: station))
        XCTAssertNil(NDBCClient.parse(text: "", station: station))
    }
}
