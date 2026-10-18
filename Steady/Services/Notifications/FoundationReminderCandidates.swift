import Foundation
import SteadyCore

enum FoundationReminderCandidates {
    static func build(state: FoundationDayState, profileID: UUID, context: FoundationReminderContext,
                      reservations: [NudgeReservation], calendar: Calendar) -> [NudgeCandidate] {
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: state.day) else { return [] }
        return state.items.compactMap { item in
            guard item.status != .done && item.status != .disabled,
                  let option = FoundationCatalog.options(for: item.kind, settings: state.settings)
                    .first(where: { $0.id == item.optionID }) else { return nil }
            let base = FoundationNotificationDelegate.prefix + profileID.uuidString + "."
                + String(state.day.timeIntervalSince1970) + "." + item.kind.rawValue
            let time: Date
            let canWait: Bool
            var origin: NudgeOrigin = .automatic
            let id: String
            if item.status == .snoozed, let until = item.snoozedUntil {
                time = Date(timeIntervalSince1970: ceil(until.timeIntervalSince1970))
                canWait = false
                id = base + ".snooze." + String(until.timeIntervalSince1970)
                if let previous = reservations.filter({ $0.kind == item.kind && $0.day == state.day && $0.id != id }).last {
                    origin = .snooze(replacingID: previous.id)
                }
            } else {
                guard let proposed = proposedTime(for: item.kind, day: state.day, context: context, calendar: calendar) else { return nil }
                time = proposed
                canWait = [.hydration, .movementBreak, .reset].contains(item.kind)
                id = base + ".automatic"
            }
            let expiry = min(dayEnd, time.addingTimeInterval(item.kind == .windDown ? 20 * 60 : 60 * 60))
            return NudgeCandidate(id: id, kind: item.kind, title: option.title, body: option.reason,
                fireAt: time, expiresAt: expiry, durationMinutes: option.minutes ?? 1, canWait: canWait, origin: origin)
        }
    }

    private static func proposedTime(for kind: FoundationKind, day: Date, context: FoundationReminderContext,
                                     calendar: Calendar) -> Date? {
        switch kind {
        case .mobility: context.wake.addingTimeInterval(10 * 60)
        case .daylight: context.wake.addingTimeInterval(30 * 60)
        case .hydration: calendar.date(bySettingHour: 12, minute: 30, second: 0, of: day)
        case .movementBreak: calendar.date(bySettingHour: 15, minute: 0, second: 0, of: day)
        case .reset: calendar.date(bySettingHour: 13, minute: 45, second: 0, of: day)
        case .windDown: context.bedtime?.windDownTime
        }
    }
}
