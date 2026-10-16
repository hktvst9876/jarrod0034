import Foundation

public enum BedtimePlanner {
    public static func plan(
        for input: BedtimePlanInput,
        calendar: Calendar = SteadyCalendar.singapore()
    ) -> BedtimePlan? {
        let tomorrow = calendar.startOfDay(for: input.tomorrow)
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: tomorrow),
              let usualWake = input.usualWakeTime.date(on: tomorrow, calendar: calendar),
              let earliestWake = calendar.date(
                bySettingHour: 5,
                minute: 30,
                second: 0,
                of: tomorrow
              ) else {
            return nil
        }

        let firstCommitment = input.commitments
            .filter {
                !$0.isAllDay
                    && $0.calendarName.caseInsensitiveCompare("Steady") != .orderedSame
                    && $0.start >= tomorrow
                    && $0.start < nextDay
            }
            .map(\.start)
            .min()

        let commitmentWake = firstCommitment.flatMap { commitment in
            calendar.date(
                byAdding: .minute,
                value: -(input.travelMinutes + input.morningRoutineMinutes),
                to: commitment
            )
        }
        let unclampedWake = min(usualWake, commitmentWake ?? usualWake)
        let wakeTime = max(unclampedWake, earliestWake)

        guard let bedtime = calendar.date(
            byAdding: .minute,
            value: -(input.sleepNeedMinutes + input.sleepLatencyMinutes),
            to: wakeTime
        ), let windowStart = calendar.date(byAdding: .minute, value: -30, to: bedtime),
        let windowEnd = calendar.date(byAdding: .minute, value: 30, to: bedtime),
        let windDown = calendar.date(byAdding: .minute, value: -input.windDownMinutes, to: bedtime),
        let caffeineCutoff = calendar.date(
            byAdding: .minute,
            value: -input.caffeineCutoffMinutes,
            to: bedtime
        ) else {
            return nil
        }

        let earlyBySeconds = usualWake.timeIntervalSince(wakeTime)
        let hasEarlyCommitment = firstCommitment != nil && wakeTime < usualWake
        let explanation = hasEarlyCommitment
            ? "Tomorrow's first commitment moves your sleep opportunity earlier."
            : "This plan protects your usual wake time and sleep need."

        return BedtimePlan(
            wakeTime: wakeTime,
            unclampedWakeTime: unclampedWake,
            bedtime: bedtime,
            bedtimeWindowStart: windowStart,
            bedtimeWindowEnd: windowEnd,
            windDownTime: windDown,
            caffeineCutoffTime: caffeineCutoff,
            firstCommitment: firstCommitment,
            isWakeTimeClamped: unclampedWake < earliestWake,
            needsEarlyWakeHeadsUp: earlyBySeconds > 60 * 60,
            explanation: explanation
        )
    }
}
