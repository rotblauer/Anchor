import XCTest
@testable import AnchorCore

final class ScoringTests: XCTestCase {
    let engine = ScoreEngine()

    func makePlace(id: String = "test", shelter: Double, fetch: Double, advisory: Bool = false) -> Place {
        let json = """
        {
          "id": "\(id)", "name": "Test", "island": "Test Island", "type": "anchorage",
          "lat": 46.9, "lon": -90.6,
          "shelter": [\(Array(repeating: String(shelter), count: 16).joined(separator: ","))],
          "fetchNm": [\(Array(repeating: String(fetch), count: 16).joined(separator: ","))],
          "bottom": "sand", "holding": "good", "advisory": \(advisory),
          "description": "test", "sources": ["test"]
        }
        """
        return try! JSONDecoder().decode(Place.self, from: Data(json.utf8))
    }

    func testAdvisoryPlacesNeverRank() {
        let calendar = ScoreEngine.localCalendar
        var components = DateComponents()
        components.year = 2026; components.month = 8; components.day = 6; components.hour = 15
        let start = calendar.date(from: components)!
        let samples = (0..<48).map { sample(speed: 5, time: start.addingTimeInterval(Double($0) * 3600)) }

        let normal = makePlace(id: "normal", shelter: 0.9, fetch: 1)
        let closed = makePlace(id: "closed", shelter: 0.9, fetch: 1, advisory: true)
        let outlooks = [
            "normal": engine.outlook(for: normal, hours: samples, calendar: calendar),
            "closed": engine.outlook(for: closed, hours: samples, calendar: calendar),
        ]
        let ranked = ScoreEngine.rank(
            places: [normal, closed], outlooks: outlooks,
            nightOf: calendar.startOfDay(for: start), calendar: calendar
        )
        XCTAssertEqual(ranked.map(\.place.id), ["normal"], "advisory places must never be recommended")
    }

    func sample(speed: Double, gust: Double? = nil, direction: Double = 0, time: Date = Date(timeIntervalSince1970: 1_786_000_000)) -> WindSample {
        WindSample(time: time, speedKt: speed, gustKt: gust ?? speed * 1.2, directionDeg: direction)
    }

    func testScoreDecreasesWithWind() {
        let exposed = makePlace(shelter: 0, fetch: 30)
        let s10 = engine.hourScore(place: exposed, sample: sample(speed: 10)).score
        let s20 = engine.hourScore(place: exposed, sample: sample(speed: 20)).score
        let s30 = engine.hourScore(place: exposed, sample: sample(speed: 30)).score
        XCTAssertGreaterThan(s10, s20)
        XCTAssertGreaterThan(s20, s30)
    }

    func testShelterBeatsExposure() {
        let sheltered = makePlace(shelter: 0.95, fetch: 0.5)
        let exposed = makePlace(shelter: 0.0, fetch: 30)
        let wind = sample(speed: 18, gust: 24)
        let shelteredScore = engine.hourScore(place: sheltered, sample: wind).score
        let exposedScore = engine.hourScore(place: exposed, sample: wind).score
        XCTAssertGreaterThan(shelteredScore, exposedScore + 20)
        XCTAssertGreaterThan(shelteredScore, 75, "protected harbor in 18 kt should still be pleasant")
    }

    func testDangerCapAppliesOnExposedLeeShore() {
        let exposed = makePlace(shelter: 0, fetch: 50)
        let result = engine.hourScore(place: exposed, sample: sample(speed: 30, gust: 38))
        XCTAssertTrue(result.dangerous)
        XCTAssertLessThanOrEqual(result.score, engine.constants.dangerCap)
        XCTAssertEqual(result.band, .avoid)
    }

    func testCalmIsExcellentEverywhere() {
        let exposed = makePlace(shelter: 0, fetch: 100)
        let result = engine.hourScore(place: exposed, sample: sample(speed: 4, gust: 6))
        XCTAssertEqual(result.band, .excellent)
    }

    func testOutlookGroupsOvernightWindows() {
        let calendar = ScoreEngine.localCalendar
        // Build 72 hours of hourly samples starting at local noon.
        var components = DateComponents()
        components.year = 2026; components.month = 8; components.day = 6; components.hour = 12
        let start = calendar.date(from: components)!
        let samples = (0..<72).map { offset in
            sample(speed: 10, direction: 270, time: start.addingTimeInterval(Double(offset) * 3600))
        }
        let place = makePlace(shelter: 0.9, fetch: 1)
        let outlook = engine.outlook(for: place, hours: samples, calendar: calendar)

        XCTAssertGreaterThanOrEqual(outlook.nights.count, 2)
        // Nights should be consecutive calendar evenings starting Aug 6.
        let expectedFirst = calendar.startOfDay(for: start)
        XCTAssertEqual(outlook.nights.first?.nightOf, expectedFirst)
        for night in outlook.nights {
            XCTAssertFalse(night.reasons.isEmpty)
            XCTAssertEqual(night.band, RatingBand(score: night.score))
        }
    }

    func testShiftWarningFiresOnBigOvernightSwing() {
        let calendar = ScoreEngine.localCalendar
        var components = DateComponents()
        components.year = 2026; components.month = 8; components.day = 6; components.hour = 18
        let start = calendar.date(from: components)!
        // Wind veers from W (270) to N (0) overnight at 15 kt.
        let samples = (0..<15).map { offset in
            sample(speed: 15, direction: offset < 8 ? 270 : 0, time: start.addingTimeInterval(Double(offset) * 3600))
        }
        let place = makePlace(shelter: 0.5, fetch: 5)
        let outlook = engine.outlook(for: place, hours: samples, calendar: calendar)
        XCTAssertEqual(outlook.nights.count, 1)
        XCTAssertTrue(outlook.nights[0].shiftWarning)
    }

    func testEdgeNightsWithoutBothSidesOfMidnightAreSkipped() {
        let calendar = ScoreEngine.localCalendar
        var components = DateComponents()
        components.year = 2026; components.month = 8; components.day = 6; components.hour = 0
        let start = calendar.date(from: components)!
        // 48 hours: Aug 6 00:00 through Aug 7 23:00. The Aug 5 night (morning
        // stub) and Aug 7 night (evening only, no morning) must both be
        // skipped; only Aug 6's complete night is ratable.
        let samples = (0..<48).map { sample(speed: 8, time: start.addingTimeInterval(Double($0) * 3600)) }
        let place = makePlace(shelter: 0.8, fetch: 2)
        let outlook = engine.outlook(for: place, hours: samples, calendar: calendar)
        XCTAssertEqual(outlook.nights.map(\.nightOf), [calendar.startOfDay(for: start)])
    }

    func testDayUseOnlyDockDoesNotRank() {
        let calendar = ScoreEngine.localCalendar
        var components = DateComponents()
        components.year = 2026; components.month = 8; components.day = 6; components.hour = 12
        let start = calendar.date(from: components)!
        let samples = (0..<48).map { sample(speed: 5, time: start.addingTimeInterval(Double($0) * 3600)) }

        let dayUseJson = """
        {
          "id": "day-use-dock", "name": "Day Dock", "island": "Test Island", "type": "dock",
          "lat": 46.9, "lon": -90.6,
          "shelter": [\(Array(repeating: "0.9", count: 16).joined(separator: ","))],
          "fetchNm": [\(Array(repeating: "1", count: 16).joined(separator: ","))],
          "bottom": "sand", "dock": {"overnight": false},
          "description": "test", "sources": ["test"]
        }
        """
        let dayUse = try! JSONDecoder().decode(Place.self, from: Data(dayUseJson.utf8))
        let anchorage = makePlace(id: "anchorage", shelter: 0.9, fetch: 1)

        let outlooks = [
            "day-use-dock": engine.outlook(for: dayUse, hours: samples, calendar: calendar),
            "anchorage": engine.outlook(for: anchorage, hours: samples, calendar: calendar),
        ]
        let ranked = ScoreEngine.rank(
            places: [dayUse, anchorage], outlooks: outlooks,
            nightOf: calendar.startOfDay(for: start), calendar: calendar
        )
        XCTAssertEqual(ranked.map(\.place.id), ["anchorage"], "day-use-only docks must not be recommended for overnight")
    }

    func testConsecutiveGoodNightsAndRanking() {
        let calendar = ScoreEngine.localCalendar
        var components = DateComponents()
        components.year = 2026; components.month = 8; components.day = 6; components.hour = 15
        let start = calendar.date(from: components)!

        // Five days of samples: calm the first two nights, storm from the north after.
        let samples = (0..<120).map { offset -> WindSample in
            let time = start.addingTimeInterval(Double(offset) * 3600)
            let calm = offset < 55
            return sample(speed: calm ? 6 : 26, gust: calm ? 8 : 34, direction: 0, time: time)
        }

        let northExposed = makePlace(id: "north-exposed", shelter: 0.1, fetch: 40)
        let northSheltered = makePlace(id: "north-sheltered", shelter: 0.95, fetch: 0.5)

        let exposedOutlook = engine.outlook(for: northExposed, hours: samples, calendar: calendar)
        let shelteredOutlook = engine.outlook(for: northSheltered, hours: samples, calendar: calendar)

        let firstNight = calendar.startOfDay(for: start)
        let exposedStreak = exposedOutlook.consecutiveGoodNights(
            from: exposedOutlook.nightIndex(of: firstNight, calendar: calendar) ?? 0)
        let shelteredStreak = shelteredOutlook.consecutiveGoodNights(
            from: shelteredOutlook.nightIndex(of: firstNight, calendar: calendar) ?? 0)
        XCTAssertGreaterThan(shelteredStreak, exposedStreak,
                             "the north-sheltered spot should stay good once the northerly arrives")

        let ranked = ScoreEngine.rank(
            places: [northExposed, northSheltered],
            outlooks: [exposedOutlook.placeId: exposedOutlook, shelteredOutlook.placeId: shelteredOutlook],
            nightOf: firstNight.addingTimeInterval(3 * 86400),
            calendar: calendar
        )
        XCTAssertEqual(ranked.first?.place.id, "north-sheltered")
    }
}
