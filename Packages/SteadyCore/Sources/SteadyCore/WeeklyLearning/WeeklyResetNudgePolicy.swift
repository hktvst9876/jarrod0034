import Foundation

/// Resetting a local journal must not reopen a notification budget on the same
/// Singapore day. A clock rollback or invalid date stays quiet conservatively.
public enum WeeklyResetNudgePolicy {
    public static func shouldStayQuiet(
        erasedAt: Date, now: Date, calendar: Calendar = SteadyCalendar.singapore()
    ) -> Bool {
        guard erasedAt.timeIntervalSinceReferenceDate.isFinite,
              now.timeIntervalSinceReferenceDate.isFinite,
              let nextDay = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: erasedAt)) else { return true }
        return now < nextDay
    }
}
