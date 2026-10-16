import Foundation
import Observation
import SteadyCore

@MainActor
@Observable
final class OnboardingViewModel {
    var step = 0
    var name = ""
    var focus = WellnessFocus.sleep
    var sleepNeedHours = 8.0
    var weekdayWake = ProfileTimeFormatting.date(for: 450)
    var weekendWake = ProfileTimeFormatting.date(for: 510)
    var strengthSessionsPerWeek = 3
    var workoutTime = DayPeriod.afternoon
    var movementsToAvoid = ""
    var lowDataMode = false
    var healthMessage: String?
    var calendarMessage: String?
    var isRequestingPermission = false

    let lastStep = 4

    func moveForward() {
        step = min(step + 1, lastStep)
    }

    func moveBack() {
        step = max(step - 1, 0)
    }

    func requestHealth(using environment: AppEnvironment) async {
        isRequestingPermission = true
        healthMessage = await environment.requestHealthAccessMessage()
        isRequestingPermission = false
    }

    func requestCalendar(using environment: AppEnvironment) async {
        isRequestingPermission = true
        calendarMessage = await environment.requestCalendarAccessMessage()
        isRequestingPermission = false
    }

    func makeProfile(completedAt: Date) -> ProfileRecord {
        ProfileRecord(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            primaryFocusRawValue: focus.rawValue,
            sleepNeedMinutes: Int((sleepNeedHours * 60).rounded()),
            weekdayWakeMinutes: ProfileTimeFormatting.minutes(from: weekdayWake),
            weekendWakeMinutes: ProfileTimeFormatting.minutes(from: weekendWake),
            strengthSessionsPerWeek: strengthSessionsPerWeek,
            preferredWorkoutTimeRawValue: workoutTime.rawValue,
            movementsToAvoid: movementsToAvoid.trimmingCharacters(in: .whitespacesAndNewlines),
            lowDataMode: lowDataMode,
            completedAt: completedAt
        )
    }
}

