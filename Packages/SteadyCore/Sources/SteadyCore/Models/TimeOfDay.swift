import Foundation

public struct TimeOfDay: Codable, Equatable, Hashable, Sendable {
    public let hour: Int
    public let minute: Int

    public init?(hour: Int, minute: Int) {
        guard (0...23).contains(hour), (0...59).contains(minute) else {
            return nil
        }

        self.hour = hour
        self.minute = minute
    }

    public func date(on day: Date, calendar: Calendar = SteadyCalendar.singapore()) -> Date? {
        let startOfDay = calendar.startOfDay(for: day)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: startOfDay)
    }

    public var minutesAfterMidnight: Int {
        (hour * 60) + minute
    }
}
