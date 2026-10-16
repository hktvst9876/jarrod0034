import Foundation

public extension FreeSlotFinder {
    /// Converts free gaps into a concrete action-sized slot, preferring the requested day period.
    static func bestFittingSlot(
        in freeSlots: [FreeSlot],
        durationMinutes: Int,
        preferredPeriod: DayPeriod? = nil,
        calendar: Calendar = SteadyCalendar.singapore()
    ) -> FreeSlot? {
        let duration = max(0, durationMinutes)
        guard duration > 0 else { return nil }

        let candidates = freeSlots.compactMap { slot -> (slot: FreeSlot, preferred: Bool)? in
            guard slot.durationMinutes >= duration else { return nil }

            if let preferredPeriod,
               let start = fittingStart(
                   in: slot,
                   minutes: duration,
                   during: preferredPeriod,
                   calendar: calendar
               ), let end = calendar.date(byAdding: .minute, value: duration, to: start) {
                return (concreteSlot(from: slot, start: start, end: end), true)
            }

            guard let end = calendar.date(byAdding: .minute, value: duration, to: slot.start) else {
                return nil
            }
            return (concreteSlot(from: slot, start: slot.start, end: end), false)
        }

        return candidates.sorted { lhs, rhs in
            if lhs.preferred != rhs.preferred { return lhs.preferred }
            return lhs.slot.start < rhs.slot.start
        }.first?.slot
    }
}

private extension FreeSlotFinder {
    static func concreteSlot(from gap: FreeSlot, start: Date, end: Date) -> FreeSlot {
        FreeSlot(
            start: start,
            end: end,
            travelAllowanceMinutes: gap.travelAllowanceMinutes,
            confidence: gap.confidence
        )
    }

    static func fittingStart(
        in slot: FreeSlot,
        minutes: Int,
        during period: DayPeriod,
        calendar: Calendar
    ) -> Date? {
        let hours: (start: Int, end: Int)
        switch period {
        case .morning: hours = (5, 12)
        case .afternoon: hours = (12, 17)
        case .evening: hours = (17, 23)
        }

        guard let periodStart = calendar.date(
            bySettingHour: hours.start,
            minute: 0,
            second: 0,
            of: slot.start
        ), let periodEnd = calendar.date(
            bySettingHour: hours.end,
            minute: 0,
            second: 0,
            of: slot.start
        ) else {
            return nil
        }

        let start = max(slot.start, periodStart)
        let availableEnd = min(slot.end, periodEnd)
        guard let end = calendar.date(byAdding: .minute, value: minutes, to: start),
              end <= availableEnd else {
            return nil
        }
        return start
    }
}
