import Foundation

public enum FreeSlotFinder {
    public static func find(
        within window: DateRange,
        busyIntervals: [BusyInterval],
        minimumDurationMinutes: Int,
        paddingMinutes: Int = 15,
        notBefore: Date? = nil,
        preferredPeriod: DayPeriod? = nil,
        confidence: SlotConfidence = .calendarDerived,
        calendar: Calendar = SteadyCalendar.singapore()
    ) -> [FreeSlot] {
        let effectiveStart = max(window.start, notBefore ?? window.start)
        guard window.end > effectiveStart else { return [] }

        let minimumMinutes = max(0, minimumDurationMinutes)
        let padding = max(0, paddingMinutes)
        let effectiveWindow = DateRange(start: effectiveStart, end: window.end)
        let mergedBusy = mergedPaddedIntervals(
            busyIntervals,
            within: effectiveWindow,
            paddingMinutes: padding
        )
        let gaps = freeGaps(in: effectiveWindow, around: mergedBusy)
            .filter { $0.durationMinutes >= minimumMinutes }

        let slots = gaps.map {
            FreeSlot(
                start: $0.start,
                end: $0.end,
                travelAllowanceMinutes: padding,
                confidence: confidence
            )
        }

        guard let preferredPeriod else {
            return slots.sorted { $0.start < $1.start }
        }

        return slots.sorted { lhs, rhs in
            let lhsMatches = canFit(
                minutes: minimumMinutes,
                in: lhs,
                during: preferredPeriod,
                calendar: calendar
            )
            let rhsMatches = canFit(
                minutes: minimumMinutes,
                in: rhs,
                during: preferredPeriod,
                calendar: calendar
            )
            if lhsMatches != rhsMatches {
                return lhsMatches
            }
            return lhs.start < rhs.start
        }
    }

    public static func totalFreeMinutes(
        within window: DateRange,
        busyIntervals: [BusyInterval],
        paddingMinutes: Int = 15,
        notBefore: Date? = nil,
        minimumGapMinutes: Int = 15
    ) -> Int {
        find(
            within: window,
            busyIntervals: busyIntervals,
            minimumDurationMinutes: minimumGapMinutes,
            paddingMinutes: paddingMinutes,
            notBefore: notBefore,
            preferredPeriod: nil,
            confidence: .calendarDerived
        ).reduce(0) { $0 + $1.durationMinutes }
    }

}

private extension FreeSlotFinder {
    static func mergedPaddedIntervals(
        _ intervals: [BusyInterval],
        within window: DateRange,
        paddingMinutes: Int
    ) -> [DateRange] {
        let paddingSeconds = Double(paddingMinutes * 60)
        let clipped = intervals.compactMap { interval -> DateRange? in
            guard interval.end > interval.start else { return nil }
            let start = max(window.start, interval.start.addingTimeInterval(-paddingSeconds))
            let end = min(window.end, interval.end.addingTimeInterval(paddingSeconds))
            guard end > start else { return nil }
            return DateRange(start: start, end: end)
        }.sorted { lhs, rhs in
            lhs.start == rhs.start ? lhs.end < rhs.end : lhs.start < rhs.start
        }

        guard var current = clipped.first else { return [] }
        var merged: [DateRange] = []
        for interval in clipped.dropFirst() {
            if interval.start <= current.end {
                current = DateRange(start: current.start, end: max(current.end, interval.end))
            } else {
                merged.append(current)
                current = interval
            }
        }
        merged.append(current)
        return merged
    }

    static func freeGaps(in window: DateRange, around busy: [DateRange]) -> [DateRange] {
        var cursor = window.start
        var gaps: [DateRange] = []

        for interval in busy {
            if interval.start > cursor {
                gaps.append(DateRange(start: cursor, end: interval.start))
            }
            cursor = max(cursor, interval.end)
        }

        if cursor < window.end {
            gaps.append(DateRange(start: cursor, end: window.end))
        }
        return gaps
    }

    static func canFit(
        minutes: Int,
        in slot: FreeSlot,
        during period: DayPeriod,
        calendar: Calendar
    ) -> Bool {
        let hours: (start: Int, end: Int)
        switch period {
        case .morning:
            hours = (5, 12)
        case .afternoon:
            hours = (12, 17)
        case .evening:
            hours = (17, 23)
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
            return false
        }

        let overlapStart = max(slot.start, periodStart)
        let overlapEnd = min(slot.end, periodEnd)
        return overlapEnd.timeIntervalSince(overlapStart) >= Double(max(0, minutes) * 60)
    }

}
