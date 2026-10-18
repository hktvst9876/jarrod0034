import Foundation

enum NudgeWindows {
    static func finite(_ date: Date) -> Bool {
        date.timeIntervalSinceReferenceDate.isFinite
    }

    static func valid(_ range: DateRange) -> Bool {
        finite(range.start) && finite(range.end) && range.end > range.start
    }

    static func blocks(context: NudgePlanningContext, dayStart: Date) -> [DateRange]? {
        let explicit = context.calendarBlocks + context.workoutBlocks + context.sleepWindows
        guard explicit.allSatisfy(valid), context.quietPeriods.allSatisfy({
            (0..<1_440).contains($0.startMinute) && (0..<1_440).contains($0.endMinute)
        }) else { return nil }
        var result = explicit
        for offset in -1...1 {
            guard let day = context.calendar.date(byAdding: .day, value: offset, to: dayStart) else { return nil }
            for quiet in context.quietPeriods {
                guard let start = localTime(quiet.startMinute, on: day, calendar: context.calendar),
                      let endDay = context.calendar.date(
                        byAdding: .day, value: quiet.endMinute <= quiet.startMinute ? 1 : 0, to: day
                      ),
                      let end = localTime(quiet.endMinute, on: endDay, calendar: context.calendar),
                      end > start else { return nil }
                result.append(DateRange(start: start, end: end))
            }
        }
        return result.sorted { $0.start == $1.start ? $0.end < $1.end : $0.start < $1.start }
    }

    /// Half-open intervals allow an action to end exactly when a block begins.
    static func firstAvailable(candidate: NudgeCandidate, blocks: [DateRange], dayEnd: Date) -> Date? {
        let duration = Double(candidate.durationMinutes) * 60
        let latestEnd = min(candidate.expiresAt, dayEnd)
        var start = candidate.fireAt
        for block in blocks {
            let end = start.addingTimeInterval(duration)
            guard finite(end), end <= latestEnd else { return nil }
            if start < block.end && block.start < end { start = block.end }
        }
        let end = start.addingTimeInterval(duration)
        return finite(end) && end <= latestEnd ? start : nil
    }

    private static func localTime(_ minute: Int, on day: Date, calendar: Calendar) -> Date? {
        calendar.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: day)
    }
}
