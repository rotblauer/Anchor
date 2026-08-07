import Foundation
import SwiftUI
import AnchorCore

/// Cached forecast state so the app still shows the last fetch when offline
/// (cell coverage in the outer islands is spotty).
struct ForecastSnapshot: Codable {
    let fetchedAt: Date
    let hours: [Date]
    let samplesByPlace: [String: [WindSample]]
    let gridPoints: [GeoPoint]
    let gridSamples: [[WindSample]]
}

enum SnapshotStore {
    static var url: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("forecast-snapshot.json")
    }

    static func save(_ snapshot: ForecastSnapshot) {
        if let data = try? JSONEncoder().encode(snapshot) {
            try? data.write(to: url, options: .atomic)
        }
    }

    static func load() -> ForecastSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(ForecastSnapshot.self, from: data)
    }
}

@Observable @MainActor
final class AppModel {
    // Static databases (bundled, verified against real sources)
    var places: [Place] = []
    var content: ContentDatabase?

    // Forecast state
    var hours: [Date] = []
    var samplesByPlace: [String: [WindSample]] = [:]
    var gridPoints: [GeoPoint] = []
    var gridSamples: [[WindSample]] = []
    var outlooks: [String: PlaceOutlook] = [:]
    var alerts: [MarineAlert] = []

    var selectedHourIndex = 0
    var isLoading = false
    var loadError: String?
    var lastUpdated: Date?

    let engine = ScoreEngine()
    let calendar = ScoreEngine.localCalendar
    private let weather: WeatherProviding
    private let alertsClient = MarineAlertsClient()

    init(weather: WeatherProviding = OpenMeteoClient()) {
        self.weather = weather
        places = (try? PlacesDatabase.loadBundled())?.places ?? []
        content = try? ContentDatabase.loadBundled()
        gridPoints = WindGrid.apostleGrid()
        restoreSnapshotIfFresh()
    }

    // MARK: - Fetching

    func refreshIfNeeded() async {
        if let updated = lastUpdated, Date().timeIntervalSince(updated) < 30 * 60 { return }
        await refresh()
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        loadError = nil
        do {
            let placePoints = places.map(\.geo)
            let forecasts = try await weather.hourlyForecasts(for: placePoints + gridPoints, days: 8)
            let placeForecasts = Array(forecasts.prefix(placePoints.count))
            let gridForecasts = Array(forecasts.dropFirst(placePoints.count))

            var samples: [String: [WindSample]] = [:]
            for (place, forecast) in zip(places, placeForecasts) {
                samples[place.id] = forecast.hours
            }
            apply(
                hours: placeForecasts.first?.hours.map(\.time) ?? gridForecasts.first?.hours.map(\.time) ?? [],
                samplesByPlace: samples,
                gridSamples: gridForecasts.map(\.hours),
                fetchedAt: Date()
            )
            SnapshotStore.save(ForecastSnapshot(
                fetchedAt: Date(), hours: hours, samplesByPlace: samplesByPlace,
                gridPoints: gridPoints, gridSamples: gridSamples
            ))
        } catch {
            loadError = "Couldn't fetch the forecast. \(error.localizedDescription)"
        }
        isLoading = false

        if let fetched = try? await alertsClient.activeAlerts() {
            alerts = fetched
        }
        // Even when the fetch fails, never keep showing an expired alert.
        alerts = alerts.filter { ($0.expires ?? .distantFuture) > Date() }
    }

    private func restoreSnapshotIfFresh() {
        guard let snapshot = SnapshotStore.load(),
              Date().timeIntervalSince(snapshot.fetchedAt) < 24 * 3600,
              snapshot.gridPoints == gridPoints,
              Set(snapshot.samplesByPlace.keys) == Set(places.map(\.id)) else { return }
        apply(hours: snapshot.hours, samplesByPlace: snapshot.samplesByPlace,
              gridSamples: snapshot.gridSamples, fetchedAt: snapshot.fetchedAt)
    }

    private func apply(hours newHours: [Date], samplesByPlace newSamples: [String: [WindSample]],
                       gridSamples newGrid: [[WindSample]], fetchedAt: Date) {
        // Remap the scrubber by wall-clock time, not raw index — after a
        // refresh the hour axis may start a day later than the cached one.
        let previousTime = selectedTime

        hours = newHours
        samplesByPlace = newSamples
        gridSamples = newGrid
        lastUpdated = fetchedAt

        var newOutlooks: [String: PlaceOutlook] = [:]
        for place in places {
            if let placeHours = newSamples[place.id] {
                newOutlooks[place.id] = engine.outlook(for: place, hours: placeHours, calendar: calendar)
            }
        }
        outlooks = newOutlooks
        pruneEndedNights()

        if let previousTime, let index = hours.firstIndex(where: { $0 >= previousTime }) {
            selectedHourIndex = index
        } else {
            jumpToNow()
        }
    }

    /// Drops nights that have already ended (a night runs through the
    /// overnight-end hour the next morning, DST-safe) so stale assessments
    /// never appear in strips or rankings. Safe to call repeatedly.
    func pruneEndedNights() {
        let now = Date()
        outlooks = outlooks.mapValues { outlook in
            PlaceOutlook(placeId: outlook.placeId, nights: outlook.nights.filter { night in
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: night.nightOf),
                      let nightEnd = calendar.date(bySettingHour: engine.constants.overnightEndHour,
                                                   minute: 0, second: 0, of: nextDay)
                else { return true }
                return nightEnd > now
            })
        }
    }

    func jumpToNow() {
        if let index = hours.firstIndex(where: { $0 >= Date() }) {
            selectedHourIndex = index
        } else {
            selectedHourIndex = max(hours.count - 1, 0)
        }
    }

    // MARK: - Selection helpers

    var selectedTime: Date? {
        hours.indices.contains(selectedHourIndex) ? hours[selectedHourIndex] : nil
    }

    var days: [Date] {
        var seen = Set<Date>()
        var result: [Date] = []
        for hour in hours {
            let day = calendar.startOfDay(for: hour)
            if seen.insert(day).inserted { result.append(day) }
        }
        return result
    }

    func selectDay(_ day: Date) {
        let evening = hours.firstIndex {
            calendar.startOfDay(for: $0) == day && calendar.component(.hour, from: $0) >= 18
        }
        if let index = evening ?? hours.firstIndex(where: { calendar.startOfDay(for: $0) == day }) {
            selectedHourIndex = index
        }
    }

    func sample(for placeId: String) -> WindSample? {
        guard let samples = samplesByPlace[placeId],
              samples.indices.contains(selectedHourIndex) else { return nil }
        return samples[selectedHourIndex]
    }

    func hourScore(for place: Place) -> HourScore? {
        sample(for: place.id).map { engine.hourScore(place: place, sample: $0) }
    }

    func gridSample(at index: Int) -> WindSample? {
        guard gridSamples.indices.contains(index),
              gridSamples[index].indices.contains(selectedHourIndex) else { return nil }
        return gridSamples[index][selectedHourIndex]
    }

    /// The night the selected time belongs to: pre-dawn hours count as the
    /// previous evening's night; daytime hours look ahead to the coming night.
    var selectedNightDate: Date? {
        guard let time = selectedTime else { return nil }
        let day = calendar.startOfDay(for: time)
        if calendar.component(.hour, from: time) < engine.constants.overnightEndHour {
            return calendar.date(byAdding: .day, value: -1, to: day)
        }
        return day
    }

    func selectedNight(for placeId: String) -> NightAssessment? {
        guard let nightDate = selectedNightDate else { return nil }
        return outlooks[placeId]?.night(of: nightDate, calendar: calendar)
    }

    func stayNights(for placeId: String) -> Int {
        guard let nightDate = selectedNightDate,
              let outlook = outlooks[placeId],
              let index = outlook.nightIndex(of: nightDate, calendar: calendar) else { return 0 }
        return outlook.consecutiveGoodNights(from: index, threshold: engine.constants.goodNightThreshold,
                                             calendar: calendar)
    }

    func ranked() -> [(place: Place, night: NightAssessment, stayNights: Int)] {
        guard let nightDate = selectedNightDate else { return [] }
        return ScoreEngine.rank(places: places, outlooks: outlooks, nightOf: nightDate,
                                calendar: calendar, goodThreshold: engine.constants.goodNightThreshold)
    }

    func places(onIsland islandName: String) -> [Place] {
        places.filter {
            $0.island.localizedCaseInsensitiveContains(islandName)
                || islandName.localizedCaseInsensitiveContains($0.island)
        }
    }
}
