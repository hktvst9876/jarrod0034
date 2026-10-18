import Foundation
import SteadyCore

extension FoundationKind {
    var title: String {
        switch self {
        case .mobility: "After waking"
        case .daylight: "Morning daylight"
        case .hydration: "With a meal"
        case .movementBreak: "Study break"
        case .reset: "Before demanding work"
        case .windDown: "Before bed"
        }
    }
}

extension FoundationStatus {
    var title: String {
        switch self {
        case .available: "Available if useful"
        case .replaced: "Your replacement"
        case .snoozed: "Snoozed for later today"
        case .done: "Done for today"
        case .disabled: "Disabled"
        }
    }
}

enum FoundationTimeFormatting {
    static func time(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = SteadyCalendar.singapore()
        formatter.timeZone = SteadyCalendar.singapore().timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: value)
    }
}
