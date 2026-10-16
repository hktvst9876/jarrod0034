import Foundation

enum ProfileTimeFormatting {
    static func date(for minutes: Int, calendar: Calendar = .current) -> Date {
        let safeMinutes = min(max(minutes, 0), 1_439)
        let start = calendar.startOfDay(for: Date())
        return calendar.date(byAdding: .minute, value: safeMinutes, to: start) ?? start
    }

    static func minutes(from date: Date, calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    static func string(for minutes: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeStyle = .short
        return formatter.string(from: date(for: minutes))
    }
}

