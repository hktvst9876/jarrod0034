import Foundation

public enum SleepAggregator {
    public static func night(
        for wakeDay: Date,
        samples: [SleepSample],
        calendar: Calendar = SteadyCalendar.singapore()
    ) -> SleepNight? {
        guard let window = attributionWindow(for: wakeDay, calendar: calendar) else {
            return nil
        }

        let sleepSamples = eligibleSamples(
            samples,
            in: window,
            calendar: calendar,
            where: { $0.countsAsSleep }
        )
        let asleepRanges = merge(sleepSamples.map(\.range))

        guard let sleepStart = asleepRanges.first?.start,
              let wakeTime = asleepRanges.last?.end else {
            return nil
        }

        let inBedSamples = eligibleSamples(
            samples,
            in: window,
            calendar: calendar,
            where: { $0 == .inBed }
        )
        let inBedRanges = merge(inBedSamples.map(\.range))
        let inBedMinutes = inBedRanges.isEmpty ? nil : durationMinutes(of: inBedRanges)

        return SleepNight(
            wakeDay: calendar.startOfDay(for: wakeDay),
            sleepStart: sleepStart,
            wakeTime: wakeTime,
            asleepMinutes: durationMinutes(of: asleepRanges),
            inBedMinutes: inBedMinutes,
            sourceCount: Set(sleepSamples.map(\.sourceID)).count
        )
    }

    public static func nights(
        endingOn finalWakeDay: Date,
        count: Int,
        samples: [SleepSample],
        calendar: Calendar = SteadyCalendar.singapore()
    ) -> [SleepNight] {
        guard count > 0 else { return [] }

        let finalDay = calendar.startOfDay(for: finalWakeDay)
        return (0..<count)
            .reversed()
            .compactMap { offset in
                guard let day = calendar.date(byAdding: .day, value: -offset, to: finalDay) else {
                    return nil
                }
                return night(for: day, samples: samples, calendar: calendar)
            }
    }
}

private extension SleepAggregator {
    struct EligibleSample {
        let range: DateRange
        let sourceID: String
    }

    static func attributionWindow(for wakeDay: Date, calendar: Calendar) -> DateRange? {
        let day = calendar.startOfDay(for: wakeDay)
        guard let previousDay = calendar.date(byAdding: .day, value: -1, to: day),
              let start = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: previousDay),
              let end = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day) else {
            return nil
        }
        return DateRange(start: start, end: end)
    }

    static func eligibleSamples(
        _ samples: [SleepSample],
        in window: DateRange,
        calendar: Calendar,
        where includesStage: (SleepStage) -> Bool
    ) -> [EligibleSample] {
        samples.compactMap { sample in
            guard includesStage(sample.stage),
                  sample.end > sample.start,
                  sample.end > window.start,
                  sample.end <= window.end,
                  !isNap(sample, calendar: calendar) else {
                return nil
            }

            let clippedStart = max(sample.start, window.start)
            let clippedEnd = min(sample.end, window.end)
            guard clippedEnd > clippedStart else { return nil }

            return EligibleSample(
                range: DateRange(start: clippedStart, end: clippedEnd),
                sourceID: sample.sourceID
            )
        }
    }

    static func isNap(_ sample: SleepSample, calendar: Calendar) -> Bool {
        guard calendar.isDate(sample.start, inSameDayAs: sample.end),
              let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: sample.start),
              let sixPM = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: sample.start) else {
            return false
        }
        return sample.start >= noon && sample.end <= sixPM
    }

    static func merge(_ ranges: [DateRange]) -> [DateRange] {
        let sorted = ranges
            .filter { $0.end > $0.start }
            .sorted { lhs, rhs in
                lhs.start == rhs.start ? lhs.end < rhs.end : lhs.start < rhs.start
            }

        guard var current = sorted.first else { return [] }
        var merged: [DateRange] = []

        for range in sorted.dropFirst() {
            if range.start <= current.end {
                current = DateRange(start: current.start, end: max(current.end, range.end))
            } else {
                merged.append(current)
                current = range
            }
        }
        merged.append(current)
        return merged
    }

    static func durationMinutes(of ranges: [DateRange]) -> Int {
        let seconds = ranges.reduce(0.0) { partial, range in
            partial + max(0, range.end.timeIntervalSince(range.start))
        }
        return Int(seconds / 60)
    }
}
