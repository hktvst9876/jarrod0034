import Foundation

extension AppEnvironment {
    func planDateLabel(_ date: Date, dayStyle: DateFormatter.Style = .none) -> String {
        let formatter = DateFormatter()
        formatter.locale = .autoupdatingCurrent
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateStyle = dayStyle
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
