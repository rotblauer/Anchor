import XCTest
@testable import AnchorCore

final class CompassTests: XCTestCase {
    func testSectorIndexAndNames() {
        XCTAssertEqual(Compass.name(forDegrees: 0), "N")
        XCTAssertEqual(Compass.name(forDegrees: 359), "N")
        XCTAssertEqual(Compass.name(forDegrees: 22.5), "NNE")
        XCTAssertEqual(Compass.name(forDegrees: 90), "E")
        XCTAssertEqual(Compass.name(forDegrees: 180), "S")
        XCTAssertEqual(Compass.name(forDegrees: 270), "W")
        XCTAssertEqual(Compass.name(forDegrees: -45), "NW")
    }

    func testInterpolationWrapsAtNorth() {
        var values = Array(repeating: 0.0, count: 16)
        values[0] = 1.0
        XCTAssertEqual(Compass.interpolate(values, atDegrees: 0), 1.0, accuracy: 1e-9)
        XCTAssertEqual(Compass.interpolate(values, atDegrees: 11.25), 0.5, accuracy: 1e-9)
        XCTAssertEqual(Compass.interpolate(values, atDegrees: 348.75), 0.5, accuracy: 1e-9)
        XCTAssertEqual(Compass.interpolate(values, atDegrees: 180), 0.0, accuracy: 1e-9)
    }

    func testAngularDifference() {
        XCTAssertEqual(Compass.angularDifference(350, 10), 20, accuracy: 1e-9)
        XCTAssertEqual(Compass.angularDifference(0, 180), 180, accuracy: 1e-9)
        XCTAssertEqual(Compass.angularDifference(90, 90), 0, accuracy: 1e-9)
    }

    func testWeightedMeanDirectionAroundNorth() {
        let mean = Compass.weightedMeanDirection([(350, 1), (10, 1)])
        XCTAssertTrue(mean < 1 || mean > 359, "mean across north should be ~0, got \(mean)")
    }
}
