import Foundation
import SteadyCore

/// One device-wide, conservative budget, including across profile replacements.
/// A reserved slot is not refunded after cancellation or an uncertain OS save.
@MainActor
enum FoundationNotificationBudget {
    private static let key = "steady.foundation.notification.reservations"

    static func history() throws -> [NudgeReservation] {
        guard let data = UserDefaults.standard.data(forKey: key) else { return [] }
        do { return try JSONDecoder().decode([NudgeReservation].self, from: data) }
        catch { throw FoundationNotificationError.invalidRequest }
    }

    static func reserve(_ values: [NudgeReservation], now: Date, calendar: Calendar) throws {
        let day = calendar.startOfDay(for: now)
        for value in values {
            guard calendar.isDate(value.day, inSameDayAs: day), let fireAt = value.fireAt,
                  fireAt > now, calendar.isDate(fireAt, inSameDayAs: day) else {
                throw FoundationNotificationError.invalidRequest
            }
        }
        try includeKnown(values, now: now, calendar: calendar)
    }

    /// Reconcile a local reservation saved before an uncertain journal/OS result.
    /// Past slots still count; losing a scheduling acknowledgement never refunds attention.
    static func includeKnown(_ values: [NudgeReservation], now: Date, calendar: Calendar) throws {
        var saved = try history()
        let day = calendar.startOfDay(for: now)
        for value in values {
            guard value.day.timeIntervalSince1970.isFinite,
                  value.fireAt.map({ $0.timeIntervalSince1970.isFinite
                      && calendar.isDate($0, inSameDayAs: value.day) }) ?? true else {
                throw FoundationNotificationError.invalidRequest
            }
            if let previous = saved.first(where: { $0.id == value.id }) {
                guard previous == value else { throw FoundationNotificationError.invalidRequest }
            } else { saved.append(value) }
        }
        let today = saved.filter { calendar.isDate($0.day, inSameDayAs: day) }
        guard Set(today.map(\.id)).count <= 3 else { throw FoundationNotificationError.invalidRequest }
        let cutoff = calendar.date(byAdding: .day, value: -14, to: day) ?? day
        saved = saved.filter { $0.day >= cutoff }
        UserDefaults.standard.set(try JSONEncoder().encode(saved), forKey: key)
    }
}
