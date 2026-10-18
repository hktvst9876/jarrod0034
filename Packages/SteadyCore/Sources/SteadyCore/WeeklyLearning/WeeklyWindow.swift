import Foundation

public struct WeeklyScope: Codable, Equatable, Sendable {
    public let profileID: UUID
    public let isSample: Bool
    public let weekStart: Date
    public let revision: String

    public init(profileID: UUID, isSample: Bool, weekStart: Date, revision: String) {
        self.profileID = profileID
        self.isSample = isSample
        self.weekStart = weekStart
        self.revision = revision
    }
}

/// A half-open Monday-to-Monday window. Future days never count as observed days.
public struct WeeklyWindow: Codable, Equatable, Sendable {
    public let start: Date
    public let endExclusive: Date
    public let observedThrough: Date
    public let elapsedDays: Int
    public var isPartial: Bool { observedThrough < endExclusive }

    public init(start: Date, endExclusive: Date, observedThrough: Date, elapsedDays: Int) {
        self.start = start
        self.endExclusive = endExclusive
        self.observedThrough = observedThrough
        self.elapsedDays = elapsedDays
    }

    public static func make(
        containing date: Date, now: Date, calendar: Calendar = SteadyCalendar.singapore()
    ) -> WeeklyWindow? {
        var mondayCalendar = calendar
        mondayCalendar.firstWeekday = 2
        guard date.timeIntervalSinceReferenceDate.isFinite,
              now.timeIntervalSinceReferenceDate.isFinite,
              let interval = mondayCalendar.dateInterval(of: .weekOfYear, for: date) else { return nil }
        let through = min(interval.end, max(interval.start, now))
        let days: Int
        if through <= interval.start {
            days = 0
        } else if through >= interval.end {
            days = 7
        } else {
            days = min(7, (mondayCalendar.dateComponents([.day], from: interval.start,
                                                       to: mondayCalendar.startOfDay(for: through)).day ?? 0) + 1)
        }
        return WeeklyWindow(start: interval.start, endExclusive: interval.end,
                            observedThrough: through, elapsedDays: days)
    }

    public func contains(_ at: Date) -> Bool {
        observedThrough > start && at.timeIntervalSinceReferenceDate.isFinite &&
            at >= start && at < endExclusive && at <= observedThrough
    }
}

public enum WeeklyObservationSource: String, Codable, Equatable, Sendable {
    case health, userReported, sample, localRecord
}

public struct WeeklySleepObservation: Codable, Equatable, Sendable {
    public let id: String
    public let day: Date
    public let actualMinutes: Double?
    public let opportunityMinutes: Double?
    public let source: WeeklyObservationSource

    public init(id: String, day: Date, actualMinutes: Double?, opportunityMinutes: Double?, source: WeeklyObservationSource) {
        self.id = id
        self.day = day
        self.actualMinutes = actualMinutes
        self.opportunityMinutes = opportunityMinutes
        self.source = source
    }
}

public struct WeeklyMovementObservation: Codable, Equatable, Sendable {
    public let id: String
    public let at: Date
    public let minutes: Int
    public let source: WeeklyObservationSource

    public init(id: String, at: Date, minutes: Int, source: WeeklyObservationSource) {
        self.id = id
        self.at = at
        self.minutes = minutes
        self.source = source
    }
}
