import Foundation

public enum SleepMetrics {
    public static func shortfall(
        endingOn finalWakeDay: Date,
        over nights: [SleepNight],
        sleepNeedMinutes: Int,
        windowDays: Int = 7,
        calendar: Calendar = SteadyCalendar.singapore()
    ) -> SleepShortfall {
        let eligible = eligibleNights(
            endingOn: finalWakeDay,
            nights: nights,
            windowDays: windowDays,
            calendar: calendar
        )
        let need = max(0, sleepNeedMinutes)
        let total = eligible.reduce(0) { partial, night in
            partial + max(0, need - night.asleepMinutes)
        }

        return SleepShortfall(
            totalMinutes: total,
            nightsTracked: eligible.count,
            windowDays: max(0, windowDays)
        )
    }

    public static func wakeConsistency(
        endingOn finalWakeDay: Date,
        over nights: [SleepNight],
        windowDays: Int = 7,
        calendar: Calendar = SteadyCalendar.singapore()
    ) -> WakeConsistencySummary? {
        let eligible = eligibleNights(
            endingOn: finalWakeDay,
            nights: nights,
            windowDays: windowDays,
            calendar: calendar
        )
        guard eligible.count >= 2 else { return nil }

        let wakeMinutes = eligible.map { minutesAfterMidnight(for: $0.wakeTime, calendar: calendar) }
        guard let anchor = wakeMinutes.first else { return nil }
        let unwrapped = wakeMinutes.map { closestEquivalent(of: $0, to: anchor) }
        let mean = unwrapped.reduce(0, +) / Double(unwrapped.count)
        let deviation = unwrapped.reduce(0) { partial, value in
            partial + abs(value - mean)
        } / Double(unwrapped.count)

        let label: WakeConsistencyLabel
        if deviation <= 30 {
            label = .steady
        } else if deviation <= 60 {
            label = .aBitIrregular
        } else {
            label = .irregular
        }

        return WakeConsistencySummary(
            meanAbsoluteDeviationMinutes: deviation,
            label: label,
            nightsTracked: eligible.count
        )
    }

    public static func coarseLabel(
        asleepMinutes: Int?,
        sleepNeedMinutes: Int
    ) -> SleepLabel {
        guard let asleepMinutes else { return .unknown }
        let difference = asleepMinutes - max(0, sleepNeedMinutes)

        if difference < -60 { return .shorter }
        if difference > 60 { return .longer }
        return .usual
    }
}

private extension SleepMetrics {
    static func eligibleNights(
        endingOn finalWakeDay: Date,
        nights: [SleepNight],
        windowDays: Int,
        calendar: Calendar
    ) -> [SleepNight] {
        guard windowDays > 0 else { return [] }
        let finalDay = calendar.startOfDay(for: finalWakeDay)
        guard let firstDay = calendar.date(
            byAdding: .day,
            value: -(windowDays - 1),
            to: finalDay
        ) else {
            return []
        }

        var latestByDay: [Date: SleepNight] = [:]
        for night in nights {
            let day = calendar.startOfDay(for: night.wakeDay)
            guard day >= firstDay, day <= finalDay else { continue }

            if let existing = latestByDay[day] {
                if night.wakeTime > existing.wakeTime {
                    latestByDay[day] = night
                }
            } else {
                latestByDay[day] = night
            }
        }
        return latestByDay.values.sorted { $0.wakeDay < $1.wakeDay }
    }

    static func minutesAfterMidnight(for date: Date, calendar: Calendar) -> Double {
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hour = Double(components.hour ?? 0)
        let minute = Double(components.minute ?? 0)
        let second = Double(components.second ?? 0)
        return (hour * 60) + minute + (second / 60)
    }

    static func closestEquivalent(of value: Double, to anchor: Double) -> Double {
        let candidates = [value - 1_440, value, value + 1_440]
        return candidates.min { abs($0 - anchor) < abs($1 - anchor) } ?? value
    }
}
