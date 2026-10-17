import Foundation
import SteadyCore
import SwiftData

extension PlanStore {
    func load(profile: ProfileRecord, sample: Bool, snapshot: PhaseOneContextSnapshot?, proposedPlan: PlanItem?,
              environment: AppEnvironment, context: ModelContext) async {
        guard !isWorking else { return }
        let ticket = UUID()
        loadID = ticket
        hasLoaded = false
        suggestedPlan = proposedPlan
        let day = environment.calendar.startOfDay(for: environment.now)
        if sessionSafetyDay != day { sessionSafetyFlags = []; sessionSafetyDay = day }
        let key = "\(profile.id.uuidString)-\(Int(day.timeIntervalSinceReferenceDate))-\(sample)"
        if loadedKey != key {
            record = nil; plan = nil; originalPlan = nil; selectedOption = nil; activeKey = nil
            message = nil; failure = nil; safetyFlags = []
            loadedKey = key
        }
        safetyFlags = (snapshot?.safetyFlags ?? []) + reportedFlags(profile, environment: environment) + sessionSafetyFlags
        do {
            let matches = try context.fetch(FetchDescriptor<PlanRecord>(predicate: #Predicate { $0.key == key }))
            record = matches.first
            if record == nil {
                let profileID = profile.id
                let candidates = try context.fetch(FetchDescriptor<PlanRecord>(
                    predicate: #Predicate { $0.profileID == profileID && $0.sampleData == sample },
                    sortBy: [SortDescriptor(\PlanRecord.updatedAt, order: .reverse)]))
                record = candidates.first { candidate in
                    guard candidate.supersededByKey == nil else { return false }
                    if let data = candidate.pendingCalendarData,
                       let pending = try? JSONDecoder().decode(CalendarWriteProposal.self, from: data),
                       environment.calendar.isDate(pending.start, inSameDayAs: day) { return true }
                    guard let value = try? candidate.plan(), let slot = value.slot,
                          value.status == .deferred || value.status == .scheduled else { return false }
                    return environment.calendar.isDate(slot.start, inSameDayAs: day)
                }
                if let previous = record {
                    record = try carryForward(previous, key: key, day: day, at: environment.now, context: context)
                }
            }
            activeKey = record?.key
            try refreshValues()
            if let record, let identifier = record.eventIdentifier {
                let state = await environment.calendar(useSampleData: sample).eventState(identifier: identifier)
                guard loadID == ticket else { return }
                if state == .missing, let plan {
                    record.eventIdentifier = nil
                    record.calendarEventDeleted = true
                    record.planData = try JSONEncoder().encode(copy(plan, status: .deferred, slot: nil))
                    record.updatedAt = environment.now
                    try context.save()
                    try refreshValues()
                    message = "The Calendar event was removed. Your plan is unscheduled and will not be recreated."
                }
            }
            hasLoaded = true
        } catch {
            context.rollback()
            failure = "Your saved plan could not be loaded. \(error.localizedDescription)"
        }
    }

    func carryForward(_ previous: PlanRecord, key: String, day: Date, at: Date, context: ModelContext) throws -> PlanRecord {
        let value = try PlanRecord(key: key, profileID: previous.profileID, day: day,
            sampleData: previous.sampleData, plan: previous.originalPlan(), at: at)
        value.originalPlanData = previous.originalPlanData
        value.planData = previous.planData
        value.selectedOptionData = previous.selectedOptionData
        value.movementNoteAtChoice = previous.movementNoteAtChoice
        value.startedAt = previous.startedAt
        value.eventIdentifier = previous.eventIdentifier
        value.calendarEventDeleted = previous.calendarEventDeleted
        value.pendingCalendarData = previous.pendingCalendarData
        previous.supersededByKey = key
        previous.eventIdentifier = nil
        previous.pendingCalendarData = nil
        context.insert(value)
        try context.save()
        return value
    }
}
