import Foundation

public enum AvailabilityWindow {
    public static func dayWindow(
        wakeTime: Date,
        bedtime: Date,
        calendar: Calendar = SteadyCalendar.singapore()
    ) -> DateRange? {
        let day = calendar.startOfDay(for: wakeTime)
        guard let sevenAM = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: day),
              let afterMorning = calendar.date(byAdding: .minute, value: 60, to: wakeTime),
              let end = calendar.date(byAdding: .minute, value: -150, to: bedtime) else {
            return nil
        }

        let start = max(sevenAM, afterMorning)
        guard end > start else { return nil }
        return DateRange(start: start, end: end)
    }
}
