import Foundation
@testable import SteadyCore

let testCalendar = SteadyCalendar.singapore()

func testDate(
    _ year: Int = 2026,
    _ month: Int = 10,
    _ day: Int = 16,
    _ hour: Int = 0,
    _ minute: Int = 0
) -> Date {
    testCalendar.date(
        from: DateComponents(
            timeZone: testCalendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour,
            minute: minute
        )
    )!
}

func testMetric(
    current: Double? = nil,
    mean: Double? = nil,
    standardDeviation: Double? = nil,
    days: Int = 30
) -> RecoveryMetric {
    RecoveryMetric(
        current: current,
        baselineMean: mean,
        baselineStandardDeviation: standardDeviation,
        baselineSampleDays: days
    )
}

func testPlan(day: Date = testDate(), minutes: Int = 45) -> PlanItem {
    PlanItem(
        id: "planned",
        day: day,
        type: .cardio,
        title: "Easy cardio",
        outcome: Outcome(
            id: "cardio",
            summary: "Comfortable aerobic movement",
            parts: [.aerobicMovement]
        ),
        minutes: minutes,
        slot: nil,
        origin: .user
    )
}

func testContext(
    sleepMinutes: Int? = 8 * 60,
    shortfallMinutes: Int? = 0,
    recoveryStatus: RecoveryStatus = .normal,
    daysSinceExercise: Int? = 0,
    freeMinutes: Int? = 120,
    freeSlots: [FreeSlot]? = nil,
    checkIn: CheckIn? = nil,
    safetyFlags: [SafetyFlag] = [],
    plannedToday: PlanItem? = nil,
    strengthDone: Int = 0,
    strengthTarget: Int = 0,
    daysLeft: Int = 5,
    strengthYesterday: Bool = false,
    plannedStrengthDay: Bool = false,
    preferredWorkoutPeriod: DayPeriod? = .afternoon,
    examMode: Bool = false,
    fallbackFocus: WellnessFocus = .general,
    userSelectedPriority: PriorityKind? = nil,
    dataGaps: Set<DataGap> = []
) -> DailyContext {
    let day = testDate()
    let sleepNight = sleepMinutes.map { minutes in
        SleepNight(
            wakeDay: day,
            sleepStart: testDate(2026, 10, 15, 23, 0),
            wakeTime: testDate(2026, 10, 16, 7, 0),
            asleepMinutes: minutes,
            sourceCount: 1
        )
    }
    let slot = FreeSlot(
        start: testDate(2026, 10, 16, 8, 0),
        end: testDate(2026, 10, 16, 20, 0),
        confidence: .calendarDerived
    )

    return DailyContext(
        date: day,
        sleep: SleepContext(
            lastNight: sleepNight,
            coarseLabel: SleepMetrics.coarseLabel(
                asleepMinutes: sleepMinutes,
                sleepNeedMinutes: 8 * 60
            ),
            shortfall7dMinutes: shortfallMinutes,
            nightsTracked: sleepMinutes == nil ? 0 : 1,
            wakeConsistency: nil,
            bedtimePlan: nil
        ),
        sleepNeedMinutes: 8 * 60,
        recovery: RecoveryContext(
            status: recoveryStatus,
            points: recoveryStatus == .learning ? nil : 1,
            reasons: [],
            daysOfBaseline: recoveryStatus == .learning ? 2 : 30
        ),
        activity: ActivityContext(
            stepsToday: nil,
            exerciseMinutesToday: nil,
            daysSinceExercise: daysSinceExercise,
            lastWorkoutEnd: nil
        ),
        availability: Availability(
            source: .calendar,
            freeSlots: freeSlots ?? [slot],
            freeMinutesToday: freeMinutes,
            firstCommitmentTomorrow: nil
        ),
        checkIn: checkIn,
        safetyFlags: safetyFlags,
        plannedToday: plannedToday,
        strengthDoneThisWeek: strengthDone,
        strengthTarget: strengthTarget,
        daysLeftInWeekIncludingToday: daysLeft,
        strengthYesterday: strengthYesterday,
        plannedStrengthDay: plannedStrengthDay,
        preferredWorkoutPeriod: preferredWorkoutPeriod,
        examMode: examMode,
        preferredFallbackFocus: fallbackFocus,
        userSelectedPriority: userSelectedPriority,
        dataGaps: dataGaps
    )
}
