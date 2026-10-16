import Foundation

public enum CheckIn: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case lowEnergy
    case shortOnTime
    case stressed
    case sore
    case nothing
    case skipped
}

public enum DataGap: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case sleep
    case activity
    case recovery
    case calendar
    case healthPermissions
}

public struct ActivityContext: Codable, Equatable, Sendable {
    public let stepsToday: Int?
    public let exerciseMinutesToday: Int?
    public let daysSinceExercise: Int?
    public let lastWorkoutEnd: Date?

    public init(
        stepsToday: Int?,
        exerciseMinutesToday: Int?,
        daysSinceExercise: Int?,
        lastWorkoutEnd: Date?
    ) {
        self.stepsToday = stepsToday.map { max(0, $0) }
        self.exerciseMinutesToday = exerciseMinutesToday.map { max(0, $0) }
        self.daysSinceExercise = daysSinceExercise.map { max(0, $0) }
        self.lastWorkoutEnd = lastWorkoutEnd
    }

    public static let missing = ActivityContext(
        stepsToday: nil,
        exerciseMinutesToday: nil,
        daysSinceExercise: nil,
        lastWorkoutEnd: nil
    )
}

public struct DailyContext: Codable, Equatable, Sendable {
    public let date: Date
    public let sleep: SleepContext
    public let sleepNeedMinutes: Int
    public let recovery: RecoveryContext
    public let activity: ActivityContext
    public let availability: Availability
    public let checkIn: CheckIn?
    public let safetyFlags: [SafetyFlag]
    public let plannedToday: PlanItem?
    public let strengthDoneThisWeek: Int
    public let strengthTarget: Int
    public let daysLeftInWeekIncludingToday: Int
    public let strengthYesterday: Bool
    public let plannedStrengthDay: Bool
    public let preferredWorkoutPeriod: DayPeriod?
    public let examMode: Bool
    public let preferredFallbackFocus: WellnessFocus
    public let userSelectedPriority: PriorityKind?
    public let dataGaps: Set<DataGap>

    public init(
        date: Date,
        sleep: SleepContext,
        sleepNeedMinutes: Int,
        recovery: RecoveryContext,
        activity: ActivityContext,
        availability: Availability,
        checkIn: CheckIn?,
        safetyFlags: [SafetyFlag],
        plannedToday: PlanItem?,
        strengthDoneThisWeek: Int,
        strengthTarget: Int,
        daysLeftInWeekIncludingToday: Int,
        strengthYesterday: Bool,
        plannedStrengthDay: Bool,
        preferredWorkoutPeriod: DayPeriod?,
        examMode: Bool,
        preferredFallbackFocus: WellnessFocus,
        userSelectedPriority: PriorityKind? = nil,
        dataGaps: Set<DataGap> = []
    ) {
        self.date = date
        self.sleep = sleep
        self.sleepNeedMinutes = max(0, sleepNeedMinutes)
        self.recovery = recovery
        self.activity = activity
        self.availability = availability
        self.checkIn = checkIn
        self.safetyFlags = safetyFlags
        self.plannedToday = plannedToday
        self.strengthDoneThisWeek = max(0, strengthDoneThisWeek)
        self.strengthTarget = max(0, strengthTarget)
        self.daysLeftInWeekIncludingToday = max(0, daysLeftInWeekIncludingToday)
        self.strengthYesterday = strengthYesterday
        self.plannedStrengthDay = plannedStrengthDay
        self.preferredWorkoutPeriod = preferredWorkoutPeriod
        self.examMode = examMode
        self.preferredFallbackFocus = preferredFallbackFocus
        self.userSelectedPriority = userSelectedPriority
        self.dataGaps = dataGaps
    }
}
