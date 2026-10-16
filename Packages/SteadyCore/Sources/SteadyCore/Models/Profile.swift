import Foundation

public enum WellnessFocus: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case sleep
    case movement
    case strength
    case energy
    case stress
    case general
}

public enum DayPeriod: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case morning
    case afternoon
    case evening
}

public enum GymAccess: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case campus
    case activeSG
    case none
}

public struct SleepPreferences: Codable, Equatable, Sendable {
    public var weekdayWakeTime: TimeOfDay
    public var weekendWakeTime: TimeOfDay
    public var sleepNeedMinutes: Int
    public var morningRoutineMinutes: Int
    public var defaultTravelMinutes: Int
    public var caffeineCutoffMinutesBeforeBed: Int

    public init(
        weekdayWakeTime: TimeOfDay,
        weekendWakeTime: TimeOfDay,
        sleepNeedMinutes: Int = 8 * 60,
        morningRoutineMinutes: Int = 45,
        defaultTravelMinutes: Int = 30,
        caffeineCutoffMinutesBeforeBed: Int = 8 * 60
    ) {
        self.weekdayWakeTime = weekdayWakeTime
        self.weekendWakeTime = weekendWakeTime
        self.sleepNeedMinutes = max(0, sleepNeedMinutes)
        self.morningRoutineMinutes = max(0, morningRoutineMinutes)
        self.defaultTravelMinutes = max(0, defaultTravelMinutes)
        self.caffeineCutoffMinutesBeforeBed = max(0, caffeineCutoffMinutesBeforeBed)
    }
}

public struct MovementPreferences: Codable, Equatable, Sendable {
    public var strengthSessionsPerWeek: Int
    public var preferredWorkoutTime: DayPeriod
    public var gymAccess: GymAccess

    public init(
        strengthSessionsPerWeek: Int = 3,
        preferredWorkoutTime: DayPeriod = .afternoon,
        gymAccess: GymAccess = .campus
    ) {
        self.strengthSessionsPerWeek = max(0, strengthSessionsPerWeek)
        self.preferredWorkoutTime = preferredWorkoutTime
        self.gymAccess = gymAccess
    }
}

public struct Profile: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var name: String
    public var primaryFocus: WellnessFocus
    public var sleep: SleepPreferences
    public var movement: MovementPreferences
    public var lowDataMode: Bool
    public var examMode: Bool
    public let createdAt: Date

    public init(
        id: UUID,
        name: String = "",
        primaryFocus: WellnessFocus,
        sleep: SleepPreferences,
        movement: MovementPreferences,
        lowDataMode: Bool = false,
        examMode: Bool = false,
        createdAt: Date
    ) {
        self.id = id
        self.name = name
        self.primaryFocus = primaryFocus
        self.sleep = sleep
        self.movement = movement
        self.lowDataMode = lowDataMode
        self.examMode = examMode
        self.createdAt = createdAt
    }
}
