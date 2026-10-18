import Foundation
import SteadyCore
import SwiftData

struct FoundationReminderContext: Sendable {
    let wake: Date
    let bedtime: BedtimePlan?
    let calendarBlocks: [DateRange]
    let workoutBlocks: [DateRange]
    let sleepWindows: [DateRange]
    let schedulingContextAvailable: Bool
}

@MainActor
enum FoundationReminderContextLoader {
    static func load(profile record: ProfileRecord, sample: Bool, environment: AppEnvironment,
                     snapshot: PhaseOneContextSnapshot?, context: ModelContext) async throws -> FoundationReminderContext? {
        guard let profile = record.domainProfile() else { return nil }
        let calendar = environment.calendar
        let now = environment.now
        let day = calendar.startOfDay(for: now)
        guard let end = calendar.date(byAdding: .day, value: 1, to: day) else { return nil }
        let range = DateRange(start: day, end: end)
        let weekday = calendar.component(.weekday, from: day)
        let usualWake = weekday == 1 || weekday == 7 ? profile.sleep.weekendWakeTime : profile.sleep.weekdayWakeTime
        guard let wake = usualWake.date(on: day, calendar: calendar) else { return nil }
        let provider = environment.calendar(useSampleData: sample)
        let calendarAvailable = await provider.accessState() == .fullAccess
        let busy = try? await provider.reschedulingBusyIntervals(in: range, excluding: nil)
        // Recompute with current preferences/events rather than trusting an open sheet's snapshot.
        let loader = PhaseOneContextLoader(health: environment.health(useSampleData: sample), calendarProvider: provider, calendar: calendar)
        let bedtime = await loader.loadBedtimePlan(at: now, preferences: profile.sleep)
        var sleeps = wake > day ? [DateRange(start: day, end: wake)] : []
        if let bedtime, bedtime.bedtime < end { sleeps.append(DateRange(start: max(day, bedtime.bedtime), end: end)) }
        let workouts = (try? await environment.health(useSampleData: sample).workoutIntervals(in: range)) ?? []
        let protected = try protectedPlans(profileID: record.id, sample: sample, range: range, now: now, context: context)
        return FoundationReminderContext(
            wake: wake, bedtime: bedtime,
            calendarBlocks: (busy ?? []).map { DateRange(start: $0.start, end: $0.end) },
            workoutBlocks: workouts + protected, sleepWindows: sleeps,
            schedulingContextAvailable: calendarAvailable && busy != nil && bedtime != nil
        )
    }

    private static func protectedPlans(profileID: UUID, sample: Bool, range: DateRange,
                                       now: Date, context: ModelContext) throws -> [DateRange] {
        let records = try context.fetch(FetchDescriptor<PlanRecord>(predicate: #Predicate {
            $0.profileID == profileID && $0.sampleData == sample
        }))
        return try records.compactMap { record in
            guard record.supersededByKey == nil else { return nil }
            let plan = try record.plan()
            guard [.walk, .mobility, .strength, .cardio].contains(plan.type),
                  plan.status != .completed && plan.status != .intentionallyRested else { return nil }
            if record.startedAt != nil, record.day == range.start {
                // No assumed finish time: remain quiet until the user finishes/stops.
                return DateRange(start: now, end: range.end)
            }
            guard let slot = plan.slot, slot.end > range.start, slot.start < range.end else { return nil }
            return DateRange(start: slot.start, end: slot.end)
        }
    }
}
