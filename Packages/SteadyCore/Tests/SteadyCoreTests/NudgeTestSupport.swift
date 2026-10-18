import Foundation
@testable import SteadyCore

func nudgeCandidate(
    _ id: String = "mobility", kind: FoundationKind = .mobility,
    hour: Int = 9, minute: Int = 0, expiryHour: Int = 20,
    minutes: Int = 3, canWait: Bool = false, day: Int = 16,
    origin: NudgeOrigin = .automatic
) -> NudgeCandidate {
    NudgeCandidate(
        id: id, kind: kind, title: "Optional action", body: "Open Steady when it suits you.",
        fireAt: testDate(2026, 10, day, hour, minute), expiresAt: testDate(2026, 10, day, expiryHour),
        durationMinutes: minutes, canWait: canWait, origin: origin
    )
}

func nudgeContext(
    hour: Int = 8, day: Int = 16, enabled: Set<FoundationKind> = Set(FoundationKind.allCases),
    completed: Set<FoundationKind> = [], quiet: [NudgeQuietPeriod] = [],
    calendarBlocks: [DateRange] = [], workouts: [DateRange] = [], sleep: [DateRange] = [],
    dismissals: [FoundationKind: Int] = [:], reservations: [NudgeReservation] = [],
    permission: Bool = true, lowData: Bool = false, safety: [SafetyFlag] = [], budget: Int = 3
) -> NudgePlanningContext {
    NudgePlanningContext(
        now: testDate(2026, 10, day, hour), day: testDate(2026, 10, day),
        calendar: testCalendar, enabledKinds: enabled, completedKinds: completed,
        quietPeriods: quiet, calendarBlocks: calendarBlocks, workoutBlocks: workouts,
        sleepWindows: sleep, dismissalCounts: dismissals, reservations: reservations,
        notificationPermission: permission, lowDataMode: lowData, safetyFlags: safety, budget: budget
    )
}

func nudgeBlock(_ start: Int, _ end: Int, day: Int = 16) -> DateRange {
    DateRange(start: testDate(2026, 10, day, start), end: testDate(2026, 10, day, end))
}
