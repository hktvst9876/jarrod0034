import Foundation
import SwiftData

extension SteadyArchiveBuilder {
    func tables(profiles: [ProfileRecord]) throws -> [String: [[String: Any]]] {
        [
            "profiles": profiles.map(profileRow),
            "plans": try context.fetch(FetchDescriptor<PlanRecord>()).map { value in
                try row(["key": value.key, "profileID": value.profileID.uuidString, "sampleData": value.sampleData,
                         "day": date(value.day), "updatedAt": date(value.updatedAt)]) {
                    ["originalPlan": try json(value.originalPlanData), "plan": try json(value.planData),
                     "selectedOption": try optionalJSON(value.selectedOptionData), "movementNoteAtChoice": optional(value.movementNoteAtChoice),
                     "startedAt": optionalDate(value.startedAt), "eventIdentifier": optional(value.eventIdentifier),
                     "calendarEventDeleted": value.calendarEventDeleted, "pendingCalendar": try optionalJSON(value.pendingCalendarData),
                     "supersededByKey": optional(value.supersededByKey)]
                }
            },
            "choices": try context.fetch(FetchDescriptor<ChoiceRecord>()).map { value in
                try row(["id": value.id, "profileID": value.profileID.uuidString, "sampleData": value.sampleData, "at": date(value.at)]) {
                    ["choice": try json(value.choiceData)]
                }
            },
            "foundationPreferences": try context.fetch(FetchDescriptor<FoundationPreferenceRecord>()).map { value in
                try row(["key": value.key, "profileID": value.profileID.uuidString, "sampleData": value.sampleData, "updatedAt": date(value.updatedAt)]) {
                    ["settings": try json(value.settingsData), "quietPeriods": try json(value.quietPeriodsData),
                     "dismissalCounts": try json(value.dismissalCountsData), "reservations": try json(value.reservationsData),
                     "nudgesEnabled": value.nudgesEnabled, "confirmedMovementNote": optional(value.confirmedMovementNote)]
                }
            },
            "foundationDays": try context.fetch(FetchDescriptor<FoundationDayRecord>()).map { value in
                try row(["key": value.key, "profileID": value.profileID.uuidString, "sampleData": value.sampleData,
                         "day": date(value.day), "updatedAt": date(value.updatedAt)]) { ["state": try json(value.stateData)] }
            },
            "foundationResponses": try context.fetch(FetchDescriptor<FoundationResponseRecord>()).map { value in
                row(["id": value.id, "profileID": value.profileID.uuidString, "sampleData": value.sampleData,
                     "day": date(value.day), "at": date(value.at)]) { ["kind": value.kindRawValue, "action": value.action] }
            },
            "foodCorrections": try context.fetch(FetchDescriptor<FoodCorrectionRecord>()).map { value in
                try row(["key": value.key, "profileID": value.profileID.uuidString, "sampleData": value.sampleData, "updatedAt": date(value.updatedAt)]) {
                    ["correction": try json(value.correctionData)]
                }
            },
            "watchSnapshots": try context.fetch(FetchDescriptor<WatchIssuedSnapshotRecord>()).map { value in
                try row(["key": value.key]) { ["revision": value.revision, "bindingDigest": value.bindingDigest, "snapshot": try json(value.snapshotData)] }
            },
            "watchReceipts": try context.fetch(FetchDescriptor<WatchActionReceiptRecord>()).map { value in
                try row(["id": value.id, "processedAt": date(value.processedAt)]) { ["receipt": try json(value.receiptData)] }
            },
            "watchMovement": try context.fetch(FetchDescriptor<WatchMovementRecord>()).map { value in
                row(["id": value.id, "profileID": value.profileID.uuidString, "sampleData": value.sampleData, "day": date(value.day)]) {
                    ["kind": value.kindRawValue, "minutes": value.minutes, "observedAt": date(value.observedAt), "receivedAt": date(value.receivedAt)]
                }
            },
            "watchMealHandoffs": try context.fetch(FetchDescriptor<WatchMealHandoffRecord>()).map { value in
                row(["id": value.id, "profileID": value.profileID.uuidString, "sampleData": value.sampleData,
                     "day": date(value.day), "consumedAt": optionalDate(value.consumedAt)]) { ["correctionID": value.correctionID] }
            },
            "weeklyReviews": try context.fetch(FetchDescriptor<WeeklyReviewRecord>()).map { value in
                try row(["key": value.key, "profileID": value.profileID.uuidString, "sampleData": value.sampleData,
                         "weekStart": date(value.weekStart), "updatedAt": date(value.updatedAt)]) { ["review": try json(value.reviewData)] }
            },
            "weeklyExperiments": try context.fetch(FetchDescriptor<WeeklyExperimentRecord>()).map { value in
                try row(["key": value.key, "profileID": value.profileID.uuidString, "sampleData": value.sampleData,
                         "weekStart": date(value.weekStart), "updatedAt": date(value.updatedAt)]) { ["experiment": try json(value.experimentData)] }
            },
            "weeklyMetrics": try context.fetch(FetchDescriptor<WeeklyMetricRecord>()).map { value in
                try row(["id": value.id, "profileID": value.profileID.uuidString, "sampleData": value.sampleData, "at": date(value.at)]) {
                    ["event": try json(value.eventData)]
                }
            }
        ]
    }

    private func profileRow(_ value: ProfileRecord) -> [String: Any] {
        row(["id": value.id.uuidString]) {
            ["name": value.name, "primaryFocus": value.primaryFocusRawValue, "sleepNeedMinutes": value.sleepNeedMinutes,
             "weekdayWakeMinutes": value.weekdayWakeMinutes, "weekendWakeMinutes": value.weekendWakeMinutes,
             "morningRoutineMinutes": value.morningRoutineMinutes, "travelMinutes": value.travelMinutes,
             "strengthSessionsPerWeek": value.strengthSessionsPerWeek, "preferredWorkoutTime": value.preferredWorkoutTimeRawValue,
             "movementsToAvoid": value.movementsToAvoid, "dietaryRules": value.dietaryRulesText, "allergies": value.allergiesText,
             "maxPricePerMealSGD": optional(value.maxPricePerMealSGD), "lowDataMode": value.lowDataMode, "examMode": value.examMode,
             "completedAt": date(value.completedAt), "lastMorningCheckInAt": optionalDate(value.lastMorningCheckInAt),
             "lastMorningCheckIn": optional(value.lastMorningCheckInRawValue), "reportedSafetySymptomAt": optionalDate(value.reportedSafetySymptomAt),
             "reportedSafetySymptom": optional(value.reportedSafetySymptomRawValue)]
        }
    }
}
