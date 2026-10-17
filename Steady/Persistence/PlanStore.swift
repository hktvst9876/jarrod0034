import Foundation
import Observation
import SteadyCore
import SwiftData

@MainActor
@Observable
final class PlanStore {
    var record: PlanRecord?
    var plan: PlanItem?
    var originalPlan: PlanItem?
    var selectedOption: AlternativeOption?
    var suggestedPlan: PlanItem?
    var hasLoaded = false
    var loadID = UUID()
    var safetyFlags: [SafetyFlag] = []
    var sessionSafetyFlags: [SafetyFlag] = []
    var isWorking = false
    var message: String?
    var failure: String?
    var loadedKey: String?
    var activeKey: String?
    var sessionSafetyDay: Date?

    var safetyMessage: SafetyMessage? {
        if case .pauseRecommendations(let value) = SafetyGate.evaluate(safetyFlags) { return value }
        return nil
    }

    func effectivePlan(priority: DailyPriority?) -> PlanItem? {
        guard let safetyMessage else { return plan ?? priority?.planA }
        guard let source = plan ?? priority?.planA else { return nil }
        return PlanItem(id: source.id, day: source.day, type: .rest, title: safetyMessage.title,
            outcome: Outcome(id: "safety", summary: safetyMessage.guidance, parts: [.dailyRoutine]),
            minutes: 0, slot: nil, origin: .priorityRule)
    }


    func refreshSafety(profile: ProfileRecord, sample: Bool, environment: AppEnvironment) async -> Bool {
        let latest = (try? await environment.health(useSampleData: sample)
            .safetyFlags(on: environment.now, calendar: environment.calendar)) ?? safetyFlags
        safetyFlags = latest + reportedFlags(profile, environment: environment) + sessionSafetyFlags
        if let safetyMessage {
            failure = safetyMessage.guidance
            return false
        }
        return true
    }

    func persist(_ value: PlanItem, original: PlanItem, selected: AlternativeOption?, action: String,
                         barrier: AlternativeBarrier?, startedAt: Date? = nil, profile: ProfileRecord, sample: Bool,
                         environment: AppEnvironment, context: ModelContext) throws {
        try validateContext(profile: profile, sample: sample, environment: environment)
        guard record?.pendingCalendarData == nil || action == "rest" || action == "later" else { throw PlanStoreError.pendingCalendar }
        let saved = try ensureRecord(original, profile: profile, sample: sample, environment: environment, context: context)
        saved.planData = try JSONEncoder().encode(value)
        saved.selectedOptionData = try selected.map { try JSONEncoder().encode($0) }
        if action == "choose" { saved.movementNoteAtChoice = profile.movementsToAvoid }
        if action == "priority" { saved.movementNoteAtChoice = nil }
        saved.startedAt = startedAt ?? (action == "complete" ? saved.startedAt : nil)
        saved.updatedAt = environment.now
        try insertChoice(action: action, barrier: barrier, optionID: selected?.id, plan: value,
                         profile: profile, sample: sample, at: environment.now, context: context)
        try context.save()
        activeKey = saved.key
        try refreshValues()
    }

    func ensureRecord(_ source: PlanItem, profile: ProfileRecord, sample: Bool,
                              environment: AppEnvironment, context: ModelContext) throws -> PlanRecord {
        if let record {
            guard record.profileID == profile.id, record.sampleData == sample,
                  record.key == currentKey(profile: profile, sample: sample, environment: environment) else { throw PlanStoreError.contextChanged }
            return record
        }
        let day = environment.calendar.startOfDay(for: environment.now)
        let key = "\(profile.id.uuidString)-\(Int(day.timeIntervalSinceReferenceDate))-\(sample)"
        let value = try PlanRecord(key: key, profileID: profile.id, day: day, sampleData: sample, plan: source, at: environment.now)
        context.insert(value)
        record = value
        activeKey = key
        return value
    }

    func insertChoice(action: String, barrier: AlternativeBarrier?, optionID: String?, plan: PlanItem,
                              profile: ProfileRecord, sample: Bool, at: Date, context: ModelContext) throws {
        let choice = SavedChoice(id: UUID().uuidString, planID: plan.id, at: at, action: action, barrier: barrier, optionID: optionID)
        context.insert(try ChoiceRecord(choice: choice, profileID: profile.id, sampleData: sample))
    }

    func refreshValues() throws {
        plan = try record?.plan()
        originalPlan = try record?.originalPlan()
        selectedOption = try record?.selectedOption()
    }

    func fail(_ error: Error, context: ModelContext) -> Bool {
        context.rollback()
        if let key = activeKey ?? loadedKey {
            record = try? context.fetch(FetchDescriptor<PlanRecord>(predicate: #Predicate { $0.key == key })).first
        }
        try? refreshValues()
        message = nil
        failure = "Could not finish saving this change. \(error.localizedDescription)"
        return false
    }

    func reportedFlags(_ profile: ProfileRecord, environment: AppEnvironment) -> [SafetyFlag] {
        guard let at = profile.reportedSafetySymptomAt,
              environment.calendar.isDate(at, inSameDayAs: environment.now),
              let raw = profile.reportedSafetySymptomRawValue, let symptom = Symptom(rawValue: raw) else { return [] }
        return [.userReported(symptom)]
    }

    func copy(_ source: PlanItem, status: PlanStatus, slot: FreeSlot?) -> PlanItem {
        PlanItem(id: source.id, day: source.day, type: source.type, title: source.title, outcome: source.outcome,
                 minutes: source.minutes, slot: slot, status: status, origin: source.origin)
    }
}

enum PlanStoreError: LocalizedError {
    case pendingCalendar
    case contextChanged
    var errorDescription: String? {
        switch self {
        case .pendingCalendar: "A Calendar change is awaiting recovery. Review and retry it before changing this plan."
        case .contextChanged: "This plan changed or belongs to an earlier day or data mode. Close alternatives, refresh, and try again."
        }
    }
}
