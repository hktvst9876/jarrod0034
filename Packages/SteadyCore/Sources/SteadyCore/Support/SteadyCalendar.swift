import Foundation

public enum SteadyCalendar {
    public static let singaporeTimeZoneIdentifier = "Asia/Singapore"

    /// A stable Gregorian calendar for Steady's Singapore-first date calculations.
    public static func singapore() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_SG")

        if let timeZone = TimeZone(identifier: singaporeTimeZoneIdentifier) {
            calendar.timeZone = timeZone
        } else if let fixedSingaporeTimeZone = TimeZone(secondsFromGMT: 8 * 60 * 60) {
            calendar.timeZone = fixedSingaporeTimeZone
        }

        calendar.firstWeekday = 2
        calendar.minimumDaysInFirstWeek = 4
        return calendar
    }
}
