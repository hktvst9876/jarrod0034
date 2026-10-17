import Foundation
import SteadyCore

@MainActor
enum RescheduleAvailabilityLoader {
    /// Looks ahead without changing the app plan or creating Calendar events.
    static func proposals(
        for plan: PlanItem,
        profile record: ProfileRecord,
        snapshot: PhaseOneContextSnapshot?,
        environment: AppEnvironment,
        sample: Bool,
        existingEventIdentifier: String?,
        safetyFlags: [SafetyFlag]
    ) async -> [RescheduleProposal] {
        guard !SafetyGate.evaluate(safetyFlags).blocksPerformanceRecommendations,
              let profile = record.domainProfile() else { return [] }
        let provider = environment.calendar(useSampleData: sample)
        guard await provider.accessState() == .fullAccess else { return [] }
        let calendar = environment.calendar
        let now = environment.now
        let earliest = now.addingTimeInterval(15 * 60)
        let today = calendar.startOfDay(for: now)
        let loader = PhaseOneContextLoader(
            health: environment.health(useSampleData: sample),
            calendarProvider: provider, calendar: calendar
        )
        var candidateSlots: [FreeSlot] = []
        for offset in 0...1 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: today),
                  let bedtime = await loader.loadBedtimePlan(at: day, preferences: profile.sleep) else { continue }
            let weekday = calendar.component(.weekday, from: day)
            let usualWake = weekday == 1 || weekday == 7
                ? profile.sleep.weekendWakeTime : profile.sleep.weekdayWakeTime
            if plan.type == .windDown {
                let start = bedtime.windDownTime
                let end = start.addingTimeInterval(Double(plan.minutes) * 60)
                guard start >= earliest, end <= bedtime.bedtime,
                      let busy = try? await provider.reschedulingBusyIntervals(
                        in: DateRange(start: start.addingTimeInterval(-15 * 60), end: end.addingTimeInterval(15 * 60)),
                        excluding: existingEventIdentifier
                      ) else { continue }
                let proposal = RescheduleProposal(id: "wind-down", planID: plan.id, title: plan.title, start: start, end: end)
                if ReschedulePlanner.validate(proposal, now: now, busyIntervals: busy, safetyFlags: safetyFlags) == .valid {
                    candidateSlots.append(FreeSlot(start: start, end: end, confidence: sample ? .manual : .calendarDerived))
                }
                continue
            }
            guard let wake = usualWake.date(on: day, calendar: calendar),
                  let range = AvailabilityWindow.dayWindow(wakeTime: wake, bedtime: bedtime.bedtime, calendar: calendar),
                  let busy = try? await provider.reschedulingBusyIntervals(
                    in: DateRange(start: range.start.addingTimeInterval(-15 * 60), end: range.end.addingTimeInterval(15 * 60)),
                    excluding: existingEventIdentifier
                  ) else { continue }
            let gaps = FreeSlotFinder.find(
                within: range, busyIntervals: busy, minimumDurationMinutes: plan.minutes,
                paddingMinutes: 15, notBefore: max(earliest, range.start),
                preferredPeriod: profile.movement.preferredWorkoutTime,
                confidence: sample ? .manual : .calendarDerived, calendar: calendar
            )
            candidateSlots += gaps.compactMap { gap in
                FreeSlotFinder.bestFittingSlot(
                    in: [gap], durationMinutes: plan.minutes,
                    preferredPeriod: profile.movement.preferredWorkoutTime, calendar: calendar
                )
            }
        }
        return ReschedulePlanner.proposals(
            for: plan, slots: candidateSlots, notBefore: earliest, safetyFlags: safetyFlags
        )
    }
}
