import Foundation
import SteadyCore
import SwiftData

@Model
final class ProfileRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var primaryFocusRawValue: String
    var sleepNeedMinutes: Int
    var weekdayWakeMinutes: Int
    var weekendWakeMinutes: Int
    var morningRoutineMinutes: Int
    var travelMinutes: Int
    var strengthSessionsPerWeek: Int
    var preferredWorkoutTimeRawValue: String
    var movementsToAvoid: String
    var dietaryRulesText: String
    var allergiesText: String
    var maxPricePerMealSGD: Double?
    var lowDataMode: Bool
    var examMode: Bool
    var completedAt: Date
    var lastMorningCheckInAt: Date?
    var lastMorningCheckInRawValue: String?
    var reportedSafetySymptomAt: Date?
    var reportedSafetySymptomRawValue: String?

    init(
        id: UUID = UUID(),
        name: String = "",
        primaryFocusRawValue: String = WellnessFocus.sleep.rawValue,
        sleepNeedMinutes: Int = 480,
        weekdayWakeMinutes: Int = 450,
        weekendWakeMinutes: Int = 510,
        morningRoutineMinutes: Int = 45,
        travelMinutes: Int = 30,
        strengthSessionsPerWeek: Int = 3,
        preferredWorkoutTimeRawValue: String = DayPeriod.afternoon.rawValue,
        movementsToAvoid: String = "",
        dietaryRulesText: String = "",
        allergiesText: String = "",
        maxPricePerMealSGD: Double? = nil,
        lowDataMode: Bool = false,
        examMode: Bool = false,
        completedAt: Date
    ) {
        self.id = id
        self.name = name
        self.primaryFocusRawValue = primaryFocusRawValue
        self.sleepNeedMinutes = sleepNeedMinutes
        self.weekdayWakeMinutes = weekdayWakeMinutes
        self.weekendWakeMinutes = weekendWakeMinutes
        self.morningRoutineMinutes = morningRoutineMinutes
        self.travelMinutes = travelMinutes
        self.strengthSessionsPerWeek = strengthSessionsPerWeek
        self.preferredWorkoutTimeRawValue = preferredWorkoutTimeRawValue
        self.movementsToAvoid = movementsToAvoid
        self.dietaryRulesText = dietaryRulesText
        self.allergiesText = allergiesText
        self.maxPricePerMealSGD = maxPricePerMealSGD
        self.lowDataMode = lowDataMode
        self.examMode = examMode
        self.completedAt = completedAt
        self.lastMorningCheckInAt = nil
        self.lastMorningCheckInRawValue = nil
        self.reportedSafetySymptomAt = nil
        self.reportedSafetySymptomRawValue = nil
    }
}

