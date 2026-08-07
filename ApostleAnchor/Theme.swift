import SwiftUI
import AnchorCore

enum Theme {
    static let deepWater = Color(red: 0.05, green: 0.16, blue: 0.28)
    static let teal = Color(red: 0.04, green: 0.43, blue: 0.50)
    static let sand = Color(red: 0.93, green: 0.87, blue: 0.73)
    static let advisory = Color(red: 0.52, green: 0.30, blue: 0.62)

    static func color(for band: RatingBand?) -> Color {
        switch band {
        case .excellent: return Color(red: 0.09, green: 0.62, blue: 0.34)
        case .good: return Color(red: 0.48, green: 0.72, blue: 0.22)
        case .fair: return Color(red: 0.93, green: 0.73, blue: 0.15)
        case .poor: return Color(red: 0.92, green: 0.47, blue: 0.13)
        case .avoid: return Color(red: 0.83, green: 0.20, blue: 0.16)
        case nil: return Color(white: 0.55)
        }
    }

    static func windColor(kt: Double) -> Color {
        switch kt {
        case ..<7: return Color(red: 0.45, green: 0.71, blue: 0.85)
        case ..<12: return Color(red: 0.30, green: 0.69, blue: 0.42)
        case ..<17: return Color(red: 0.93, green: 0.79, blue: 0.20)
        case ..<22: return Color(red: 0.95, green: 0.56, blue: 0.15)
        case ..<28: return Color(red: 0.89, green: 0.26, blue: 0.16)
        default: return Color(red: 0.62, green: 0.19, blue: 0.60)
        }
    }
}

/// Formatters pinned to the islands' timezone (America/Chicago) so the app
/// reads correctly no matter where the phone thinks it is.
enum Fmt {
    static let islandsTimeZone = TimeZone(identifier: "America/Chicago") ?? .current

    private static func formatter(_ format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.timeZone = islandsTimeZone
        formatter.dateFormat = format
        return formatter
    }

    static let dayChip = formatter("EEE d")
    static let hourLabel = formatter("EEE h a")
    static let nightLabel = formatter("EEE, MMM d")
    static let weekdayLetter = formatter("EEEEE")
    static let dayNumber = formatter("d")
    static let timestamp = formatter("MMM d, h:mm a")

    static func kt(_ value: Double) -> String { "\(Int(value.rounded())) kt" }

    static func windSummary(_ sample: WindSample) -> String {
        var text = "\(Compass.name(forDegrees: sample.directionDeg)) \(Int(sample.speedKt.rounded())) kt"
        if sample.gustKt >= sample.speedKt + 4 {
            text += " g\(Int(sample.gustKt.rounded()))"
        }
        return text
    }
}
