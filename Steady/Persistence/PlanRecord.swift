import Foundation
import SwiftData
import SteadyCore

/// Only app-owned choices are stored. Raw Health and Calendar records stay with Apple.
@Model
final class PlanRecord {
    @Attribute(.unique) var key: String
    var profileID: UUID
    var day: Date
    var sampleData: Bool
    var originalPlanData: Data
    var planData: Data
    var selectedOptionData: Data?
    var movementNoteAtChoice: String?
    var startedAt: Date?
    var eventIdentifier: String?
    var calendarEventDeleted: Bool
    var pendingCalendarData: Data?
    var supersededByKey: String?
    var updatedAt: Date

    init(key: String, profileID: UUID, day: Date, sampleData: Bool, plan: PlanItem, at: Date) throws {
        self.key = key
        self.profileID = profileID
        self.day = day
        self.sampleData = sampleData
        self.originalPlanData = try JSONEncoder().encode(plan)
        self.planData = try JSONEncoder().encode(plan)
        self.selectedOptionData = nil
        self.movementNoteAtChoice = nil
        self.startedAt = nil
        self.eventIdentifier = nil
        self.calendarEventDeleted = false
        self.pendingCalendarData = nil
        self.supersededByKey = nil
        self.updatedAt = at
    }

    func plan() throws -> PlanItem { try JSONDecoder().decode(PlanItem.self, from: planData) }
    func originalPlan() throws -> PlanItem { try JSONDecoder().decode(PlanItem.self, from: originalPlanData) }
    func selectedOption() throws -> AlternativeOption? {
        try selectedOptionData.map { try JSONDecoder().decode(AlternativeOption.self, from: $0) }
    }
}
