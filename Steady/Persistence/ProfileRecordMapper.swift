import Foundation
import SteadyCore

extension ProfileRecord {
    func domainProfile() -> Profile? {
        guard let weekdayWake = timeOfDay(from: weekdayWakeMinutes),
              let weekendWake = timeOfDay(from: weekendWakeMinutes) else {
            return nil
        }

        return Profile(
            id: id,
            name: name,
            primaryFocus: WellnessFocus(rawValue: primaryFocusRawValue) ?? .general,
            sleep: SleepPreferences(
                weekdayWakeTime: weekdayWake,
                weekendWakeTime: weekendWake,
                sleepNeedMinutes: sleepNeedMinutes,
                morningRoutineMinutes: morningRoutineMinutes,
                defaultTravelMinutes: travelMinutes
            ),
            movement: MovementPreferences(
                strengthSessionsPerWeek: strengthSessionsPerWeek,
                preferredWorkoutTime: DayPeriod(rawValue: preferredWorkoutTimeRawValue) ?? .afternoon,
                gymAccess: .campus
            ),
            lowDataMode: lowDataMode,
            examMode: examMode,
            createdAt: completedAt
        )
    }

    private func timeOfDay(from minutes: Int) -> TimeOfDay? {
        let safeMinutes = min(max(minutes, 0), 1_439)
        return TimeOfDay(hour: safeMinutes / 60, minute: safeMinutes % 60)
    }
}

