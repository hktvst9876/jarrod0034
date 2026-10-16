import Foundation
import SteadyCore

extension PhaseOneContextLoader {
    func loadAvailability(
        at now: Date,
        sleepPreferences: SleepPreferences,
        bedtimePlan: BedtimePlan?,
        preferredPeriod: DayPeriod,
        manualFreeMinutes: Int?
    ) async -> Availability {
        let state = await calendarProvider.accessState()
        guard state == .fullAccess else {
            return manualAvailability(minutes: manualFreeMinutes)
        }
        let dayStart = calendar.startOfDay(for: now)
        let weekday = calendar.component(.weekday, from: dayStart)
        let wakeTimeOfDay = weekday == 1 || weekday == 7
            ? sleepPreferences.weekendWakeTime
            : sleepPreferences.weekdayWakeTime
        guard let wakeTime = wakeTimeOfDay.date(on: dayStart, calendar: calendar),
              let bedtime = bedtimePlan?.bedtime,
              let range = AvailabilityWindow.dayWindow(
                wakeTime: wakeTime,
                bedtime: bedtime,
                calendar: calendar
              ),
              let tomorrow = calendar.date(byAdding: .day, value: 1, to: dayStart),
              let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: dayStart) else {
            return manualAvailability(minutes: manualFreeMinutes)
        }
        do {
            let busy = try await calendarProvider.busyIntervals(in: range)
            let slots = FreeSlotFinder.find(
                within: range,
                busyIntervals: busy,
                minimumDurationMinutes: 15,
                paddingMinutes: 15,
                notBefore: now,
                preferredPeriod: preferredPeriod,
                calendar: calendar
            )
            let tomorrowCommitments = try await calendarProvider.commitments(
                in: DateRange(start: tomorrow, end: dayAfterTomorrow)
            )
            let first = tomorrowCommitments.filter { !$0.isAllDay }.map(\.start).min()
            return Availability(
                source: .calendar,
                freeSlots: slots,
                freeMinutesToday: slots.reduce(0) { $0 + $1.durationMinutes },
                firstCommitmentTomorrow: first
            )
        } catch {
            return manualAvailability(minutes: manualFreeMinutes)
        }
    }

    func loadBedtimePlan(at now: Date, preferences: SleepPreferences) async -> BedtimePlan? {
        let today = calendar.startOfDay(for: now)
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: today),
              let dayAfterTomorrow = calendar.date(byAdding: .day, value: 2, to: today) else {
            return nil
        }
        let state = await calendarProvider.accessState()
        let commitments: [CalendarCommitment]
        if state == .fullAccess {
            commitments = (try? await calendarProvider.commitments(
                in: DateRange(start: tomorrow, end: dayAfterTomorrow)
            )) ?? []
        } else {
            commitments = []
        }
        let weekday = calendar.component(.weekday, from: tomorrow)
        let wakeTime = weekday == 1 || weekday == 7
            ? preferences.weekendWakeTime
            : preferences.weekdayWakeTime
        return BedtimePlanner.plan(
            for: BedtimePlanInput(
                tomorrow: tomorrow,
                usualWakeTime: wakeTime,
                commitments: commitments,
                travelMinutes: preferences.defaultTravelMinutes,
                morningRoutineMinutes: preferences.morningRoutineMinutes,
                sleepNeedMinutes: preferences.sleepNeedMinutes,
                caffeineCutoffMinutes: preferences.caffeineCutoffMinutesBeforeBed
            ),
            calendar: calendar
        )
    }

    private func manualAvailability(minutes: Int?) -> Availability {
        Availability(
            source: minutes == nil ? .unknown : .manualMinutes,
            freeSlots: [],
            freeMinutesToday: minutes,
            firstCommitmentTomorrow: nil
        )
    }
}
