import Foundation

public struct NudgePlanningContext: Codable, Equatable, Sendable {
    public let now: Date
    public let day: Date
    public let calendar: Calendar
    public let enabledKinds: Set<FoundationKind>
    public let completedKinds: Set<FoundationKind>
    public let quietPeriods: [NudgeQuietPeriod]
    public let calendarBlocks: [DateRange]
    public let workoutBlocks: [DateRange]
    public let sleepWindows: [DateRange]
    public let dismissalCounts: [FoundationKind: Int]
    public let reservations: [NudgeReservation]
    public let notificationPermission: Bool
    public let lowDataMode: Bool
    public let safetyFlags: [SafetyFlag]
    public let budget: Int

    public init(
        now: Date, day: Date, calendar: Calendar = SteadyCalendar.singapore(),
        enabledKinds: Set<FoundationKind> = Set(FoundationKind.allCases),
        completedKinds: Set<FoundationKind> = [], quietPeriods: [NudgeQuietPeriod] = [],
        calendarBlocks: [DateRange] = [], workoutBlocks: [DateRange] = [],
        sleepWindows: [DateRange] = [], dismissalCounts: [FoundationKind: Int] = [:],
        reservations: [NudgeReservation] = [], notificationPermission: Bool = false,
        lowDataMode: Bool = false, safetyFlags: [SafetyFlag] = [], budget: Int = 3
    ) {
        self.now = now
        self.day = day
        self.calendar = calendar
        self.enabledKinds = enabledKinds
        self.completedKinds = completedKinds
        self.quietPeriods = quietPeriods
        self.calendarBlocks = calendarBlocks
        self.workoutBlocks = workoutBlocks
        self.sleepWindows = sleepWindows
        self.dismissalCounts = dismissalCounts
        self.reservations = reservations
        self.notificationPermission = notificationPermission
        self.lowDataMode = lowDataMode
        self.safetyFlags = safetyFlags
        self.budget = budget
    }
}
