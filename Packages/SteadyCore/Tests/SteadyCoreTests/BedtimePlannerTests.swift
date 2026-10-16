import Foundation
import Testing
@testable import SteadyCore

@Suite("Bedtime planner")
struct BedtimePlannerTests {
    @Test("Usual wake time drives an empty-calendar plan")
    func usualWakePlan() throws {
        let plan = try #require(BedtimePlanner.plan(for: input(commitments: [])))

        #expect(plan.wakeTime == testDate(2026, 10, 17, 7, 30))
        #expect(plan.bedtime == testDate(2026, 10, 16, 23, 15))
        #expect(plan.bedtimeWindowStart == testDate(2026, 10, 16, 22, 45))
        #expect(plan.bedtimeWindowEnd == testDate(2026, 10, 16, 23, 45))
        #expect(plan.windDownTime == testDate(2026, 10, 16, 22, 30))
        #expect(plan.caffeineCutoffTime == testDate(2026, 10, 16, 15, 15))
    }

    @Test("An early event accounts for travel and the morning routine")
    func earlyCommitment() throws {
        let event = commitment(startHour: 8)
        let plan = try #require(BedtimePlanner.plan(for: input(commitments: [event])))

        #expect(plan.firstCommitment == testDate(2026, 10, 17, 8))
        #expect(plan.wakeTime == testDate(2026, 10, 17, 6, 45))
        #expect(plan.bedtime == testDate(2026, 10, 16, 22, 30))
        #expect(!plan.needsEarlyWakeHeadsUp)
    }

    @Test("Wake times earlier than 05:30 are clamped and flagged")
    func clampsVeryEarlyWake() throws {
        let event = commitment(startHour: 6)
        let plan = try #require(BedtimePlanner.plan(for: input(commitments: [event])))

        #expect(plan.unclampedWakeTime == testDate(2026, 10, 17, 4, 45))
        #expect(plan.wakeTime == testDate(2026, 10, 17, 5, 30))
        #expect(plan.isWakeTimeClamped)
        #expect(plan.needsEarlyWakeHeadsUp)
    }

    @Test("All-day and Steady-calendar events are ignored")
    func ignoresExcludedEvents() throws {
        let allDay = CalendarCommitment(
            id: "all-day",
            start: testDate(2026, 10, 17),
            end: testDate(2026, 10, 18),
            isAllDay: true,
            calendarName: "School"
        )
        let steady = CalendarCommitment(
            id: "steady",
            start: testDate(2026, 10, 17, 6),
            end: testDate(2026, 10, 17, 7),
            isAllDay: false,
            calendarName: "steady"
        )
        let plan = try #require(BedtimePlanner.plan(for: input(commitments: [allDay, steady])))
        #expect(plan.firstCommitment == nil)
        #expect(plan.wakeTime == testDate(2026, 10, 17, 7, 30))
    }

    @Test("Events outside tomorrow do not affect the plan")
    func ignoresOtherDays() throws {
        let event = CalendarCommitment(
            id: "later",
            start: testDate(2026, 10, 18, 7),
            end: testDate(2026, 10, 18, 8),
            isAllDay: false,
            calendarName: "School"
        )
        let plan = try #require(BedtimePlanner.plan(for: input(commitments: [event])))
        #expect(plan.firstCommitment == nil)
    }
}

private extension BedtimePlannerTests {
    func input(commitments: [CalendarCommitment]) -> BedtimePlanInput {
        BedtimePlanInput(
            tomorrow: testDate(2026, 10, 17),
            usualWakeTime: TimeOfDay(hour: 7, minute: 30)!,
            commitments: commitments,
            travelMinutes: 30,
            morningRoutineMinutes: 45,
            sleepNeedMinutes: 8 * 60
        )
    }

    func commitment(startHour: Int) -> CalendarCommitment {
        CalendarCommitment(
            id: "class-\(startHour)",
            start: testDate(2026, 10, 17, startHour),
            end: testDate(2026, 10, 17, startHour + 1),
            isAllDay: false,
            calendarName: "School"
        )
    }
}
