import Foundation

/// Tunable constants for the anchorage-suitability model.
///
/// The model: effective wind = speed blended with gusts. The place's 16-sector
/// shelter profile turns that into felt stress (even a fully sheltered bay
/// feels some wind aloft), amplified by how much open-water fetch the wind has
/// to build waves before arriving. Stress maps to a 0–100 score through a
/// deadband + power curve, with hard caps when strong wind blows onto an
/// exposed spot (a lee shore — the classic anchoring danger).
public struct ScoreConstants: Sendable {
    public var gustWeight = 0.5
    public var baseStressFactor = 0.32
    public var fetchSaturationNm = 25.0
    public var fetchFloor = 0.5
    public var penaltyDeadbandKt = 4.0
    public var penaltyExponent = 1.35
    public var penaltyScale = 1.8
    public var cautionKt = 17.0
    public var dangerKt = 25.0
    public var exposureForCaps = 0.45
    public var cautionCap = 55.0
    public var dangerCap = 22.0
    /// Local hour the overnight window opens (inclusive) and closes (exclusive).
    public var overnightStartHour = 18
    public var overnightEndHour = 9
    /// Minimum samples required to rate a night (partial nights are skipped).
    public var minSamplesPerNight = 6
    public var goodNightThreshold = 65.0
    /// Overnight direction swing (deg) at meaningful wind that triggers a warning.
    public var shiftAngleDeg = 80.0
    public var shiftMinWindKt = 9.0
    public init() {}
}

public enum RatingBand: String, CaseIterable, Codable, Sendable {
    case excellent, good, fair, poor, avoid

    public init(score: Double) {
        switch score {
        case 80...: self = .excellent
        case 65..<80: self = .good
        case 50..<65: self = .fair
        case 30..<50: self = .poor
        default: self = .avoid
        }
    }

    public var label: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        case .avoid: return "Avoid"
        }
    }

    public var sortOrder: Int {
        switch self {
        case .excellent: return 0
        case .good: return 1
        case .fair: return 2
        case .poor: return 3
        case .avoid: return 4
        }
    }
}

public struct HourScore: Sendable {
    public let time: Date
    public let score: Double
    public let effectiveWindKt: Double
    public let directionDeg: Double
    public let exposure: Double
    public let dangerous: Bool

    public var band: RatingBand { RatingBand(score: score) }
}

/// How one place fares for one night at anchor (evening through the next morning).
public struct NightAssessment: Identifiable, Sendable {
    public var id: Date { nightOf }
    /// Start-of-day date of the evening this night begins.
    public let nightOf: Date
    public let score: Double
    public let band: RatingBand
    public let minHourScore: Double
    public let meanWindKt: Double
    public let maxGustKt: Double
    public let dominantDirectionDeg: Double
    public let meanExposure: Double
    public let shiftWarning: Bool
    public let dangerous: Bool
    public let reasons: [String]
}

public struct PlaceOutlook: Sendable {
    public let placeId: String
    public let nights: [NightAssessment]

    public init(placeId: String, nights: [NightAssessment]) {
        self.placeId = placeId
        self.nights = nights
    }

    /// Number of consecutive calendar nights rated at or above `threshold`,
    /// starting at `index`. A gap in the nights array (a night that couldn't
    /// be assessed) breaks the streak rather than being skipped over.
    public func consecutiveGoodNights(from index: Int, threshold: Double = 65,
                                      calendar: Calendar = ScoreEngine.localCalendar) -> Int {
        guard index >= 0, index < nights.count else { return 0 }
        var count = 0
        var expected = nights[index].nightOf
        for night in nights[index...] {
            guard night.nightOf == expected, night.score >= threshold else { break }
            count += 1
            expected = calendar.date(byAdding: .day, value: 1, to: expected) ?? expected
        }
        return count
    }

    public func night(of date: Date, calendar: Calendar) -> NightAssessment? {
        let day = calendar.startOfDay(for: date)
        return nights.first { $0.nightOf == day }
    }

    public func nightIndex(of date: Date, calendar: Calendar) -> Int? {
        let day = calendar.startOfDay(for: date)
        return nights.firstIndex { $0.nightOf == day }
    }
}

public struct ScoreEngine: Sendable {
    public var constants: ScoreConstants
    /// Local calendar for the Apostle Islands (America/Chicago).
    public static var localCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago") ?? .current
        return calendar
    }

    public init(constants: ScoreConstants = ScoreConstants()) {
        self.constants = constants
    }

    public func effectiveWindKt(speedKt: Double, gustKt: Double) -> Double {
        speedKt * (1 - constants.gustWeight) + max(gustKt, speedKt) * constants.gustWeight
    }

    public func hourScore(place: Place, sample: WindSample) -> HourScore {
        let effective = effectiveWindKt(speedKt: sample.speedKt, gustKt: sample.gustKt)
        let shelter = min(1, max(0, Compass.interpolate(place.shelter, atDegrees: sample.directionDeg)))
        let exposure = 1 - shelter
        let fetch = max(0, Compass.interpolate(place.fetchNm, atDegrees: sample.directionDeg))
        let fetchFactor = constants.fetchFloor
            + (1 - constants.fetchFloor) * min(fetch, constants.fetchSaturationNm) / constants.fetchSaturationNm
        let stress = effective * (constants.baseStressFactor + (1 - constants.baseStressFactor) * exposure * fetchFactor)

        var score = 100.0
        let overDeadband = stress - constants.penaltyDeadbandKt
        if overDeadband > 0 {
            score -= min(100, pow(overDeadband, constants.penaltyExponent) * constants.penaltyScale)
        }

        var dangerous = false
        if exposure >= constants.exposureForCaps {
            if effective >= constants.dangerKt {
                score = min(score, constants.dangerCap)
                dangerous = true
            } else if effective >= constants.cautionKt {
                score = min(score, constants.cautionCap)
            }
        }

        return HourScore(
            time: sample.time,
            score: max(0, score),
            effectiveWindKt: effective,
            directionDeg: sample.directionDeg,
            exposure: exposure,
            dangerous: dangerous
        )
    }

    /// Groups hourly samples into overnight windows (evening → next morning)
    /// and assesses each night.
    public func outlook(for place: Place, hours: [WindSample], calendar: Calendar = ScoreEngine.localCalendar) -> PlaceOutlook {
        var byNight: [Date: [WindSample]] = [:]
        for sample in hours {
            let hour = calendar.component(.hour, from: sample.time)
            let day = calendar.startOfDay(for: sample.time)
            if hour >= constants.overnightStartHour {
                byNight[day, default: []].append(sample)
            } else if hour < constants.overnightEndHour {
                if let previousDay = calendar.date(byAdding: .day, value: -1, to: day) {
                    byNight[previousDay, default: []].append(sample)
                }
            }
        }

        // A ratable night needs coverage on both sides of midnight — otherwise
        // the trailing forecast day (evening-only) or the leading morning
        // stub would be presented as a fully assessed night.
        let nights = byNight
            .filter { _, samples in
                guard samples.count >= constants.minSamplesPerNight else { return false }
                let hourValues = samples.map { calendar.component(.hour, from: $0.time) }
                return hourValues.contains { $0 >= constants.overnightStartHour }
                    && hourValues.contains { $0 < constants.overnightEndHour }
            }
            .sorted { $0.key < $1.key }
            .map { night, samples in
                assessNight(place: place, nightOf: night, samples: samples.sorted { $0.time < $1.time })
            }

        return PlaceOutlook(placeId: place.id, nights: nights)
    }

    func assessNight(place: Place, nightOf: Date, samples: [WindSample]) -> NightAssessment {
        let hourScores = samples.map { hourScore(place: place, sample: $0) }
        let scores = hourScores.map(\.score)
        let minScore = scores.min() ?? 0
        let meanScore = scores.reduce(0, +) / Double(max(1, scores.count))
        let combined = 0.65 * minScore + 0.35 * meanScore

        let meanWind = hourScores.map(\.effectiveWindKt).reduce(0, +) / Double(max(1, hourScores.count))
        let maxGust = samples.map(\.gustKt).max() ?? 0
        let meanExposure = hourScores.map(\.exposure).reduce(0, +) / Double(max(1, hourScores.count))
        let dominantDirection = Compass.weightedMeanDirection(
            samples.map { (directionDeg: $0.directionDeg, weight: max(0.1, $0.speedKt)) }
        )
        let dangerous = hourScores.contains { $0.dangerous }

        // Direction swing at meaningful wind speed: anchored boats care because
        // the boat swings and yesterday's lee can become tonight's lee shore.
        var shiftWarning = false
        let windy = samples.filter { effectiveWindKt(speedKt: $0.speedKt, gustKt: $0.gustKt) >= constants.shiftMinWindKt }
        if let first = windy.first {
            for sample in windy.dropFirst()
            where Compass.angularDifference(first.directionDeg, sample.directionDeg) >= constants.shiftAngleDeg {
                shiftWarning = true
                break
            }
        }

        let reasons = nightReasons(
            meanWind: meanWind, maxGust: maxGust, dominantDirection: dominantDirection,
            meanExposure: meanExposure, dangerous: dangerous, shiftWarning: shiftWarning,
            place: place
        )

        return NightAssessment(
            nightOf: nightOf,
            score: combined,
            band: RatingBand(score: combined),
            minHourScore: minScore,
            meanWindKt: meanWind,
            maxGustKt: maxGust,
            dominantDirectionDeg: dominantDirection,
            meanExposure: meanExposure,
            shiftWarning: shiftWarning,
            dangerous: dangerous,
            reasons: reasons
        )
    }

    func nightReasons(meanWind: Double, maxGust: Double, dominantDirection: Double,
                      meanExposure: Double, dangerous: Bool, shiftWarning: Bool,
                      place: Place) -> [String] {
        var reasons: [String] = []
        let directionName = Compass.name(forDegrees: dominantDirection)

        var windText = "Overnight wind \(directionName) around \(Int(meanWind.rounded())) kt"
        if maxGust >= meanWind + 5 {
            windText += ", gusts to \(Int(maxGust.rounded())) kt"
        }
        reasons.append(windText)

        let fetch = Compass.interpolate(place.fetchNm, atDegrees: dominantDirection)
        if dangerous {
            reasons.append("Strong \(directionName) wind blows straight in — a dangerous lee shore. Avoid.")
        } else if meanExposure < 0.25 {
            reasons.append("Well sheltered from \(directionName) — this spot is made for this forecast.")
        } else if meanExposure < 0.55 {
            reasons.append("Partly open to \(directionName); expect some chop working in.")
        } else if fetch >= 15 {
            reasons.append("Open to \(directionName) with \(Int(fetch.rounded())) nm of fetch — waves will build.")
        } else {
            reasons.append("Open to \(directionName), though limited fetch keeps waves modest.")
        }

        if shiftWarning {
            reasons.append("Wind direction swings substantially overnight — check swing room and reset risk.")
        }

        if place.canAnchor {
            switch place.holding {
            case .good: break
            case .fair: reasons.append("Holding is only fair here — set the anchor well.")
            case .poor: reasons.append("Poor holding reported — consider a dock instead if it pipes up.")
            case .unknown: break
            }
        }

        return reasons
    }

    /// Ranks places for a given night: best score first, ties broken by how many
    /// consecutive good nights follow (longer stays win), then by name.
    public static func rank(
        places: [Place],
        outlooks: [String: PlaceOutlook],
        nightOf: Date,
        calendar: Calendar = ScoreEngine.localCalendar,
        goodThreshold: Double = 65
    ) -> [(place: Place, night: NightAssessment, stayNights: Int)] {
        var ranked: [(place: Place, night: NightAssessment, stayNights: Int)] = []
        // Skip advisory entries and dock-only places whose data explicitly says
        // overnight stays are not allowed (day-use docks).
        for place in places where !place.advisory && (place.canAnchor || place.dock?.overnight != false) {
            guard let outlook = outlooks[place.id],
                  let index = outlook.nightIndex(of: nightOf, calendar: calendar) else { continue }
            let night = outlook.nights[index]
            let stay = outlook.consecutiveGoodNights(from: index, threshold: goodThreshold, calendar: calendar)
            ranked.append((place, night, stay))
        }
        return ranked.sorted {
            if $0.night.score != $1.night.score { return $0.night.score > $1.night.score }
            if $0.stayNights != $1.stayNights { return $0.stayNights > $1.stayNights }
            return $0.place.name < $1.place.name
        }
    }
}
