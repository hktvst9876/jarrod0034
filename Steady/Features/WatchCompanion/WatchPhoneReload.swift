import Foundation
import SteadyCore
import SwiftData

extension WatchPhoneCoordinator {
    /// Refresh registered UI models using committed values only. Never roll back the shared context.
    func reloadCommittedState(action: WatchAction, profile: ProfileRecord, sample: Bool,
                              today: TodayViewModel, plans: PlanStore, foundations: FoundationStore,
                              environment: AppEnvironment, context: ModelContext, transaction: ModelContext) throws {
        guard !context.hasChanges else { throw WatchPhoneError.busy }
        do {
            switch action.kind {
            case .chooseAlternative:
                let key = plans.currentKey(profile: profile, sample: sample, environment: environment)
                guard let committed = try transaction.fetch(FetchDescriptor<PlanRecord>(predicate: #Predicate { $0.key == key })).first else {
                    throw WatchPhoneError.unavailable
                }
                let existing = try context.fetch(FetchDescriptor<PlanRecord>(predicate: #Predicate { $0.key == key })).first
                let row = try existing ?? PlanRecord(key: key, profileID: profile.id, day: action.day,
                    sampleData: sample, plan: committed.originalPlan(), at: committed.updatedAt)
                if row.modelContext == nil { context.insert(row) }
                row.originalPlanData = committed.originalPlanData; row.planData = committed.planData
                row.selectedOptionData = committed.selectedOptionData; row.movementNoteAtChoice = committed.movementNoteAtChoice
                row.startedAt = committed.startedAt; row.eventIdentifier = committed.eventIdentifier
                row.calendarEventDeleted = committed.calendarEventDeleted; row.pendingCalendarData = committed.pendingCalendarData
                row.supersededByKey = committed.supersededByKey; row.updatedAt = committed.updatedAt
                try context.save()
                plans.record = row; plans.activeKey = key; plans.loadedKey = key
                try plans.refreshValues()
                plans.hasLoaded = true
            case .foundationDone:
                let preferenceKey = "\(profile.id.uuidString)-\(sample)"
                let dayKey = "\(preferenceKey)-\(Int(action.day.timeIntervalSinceReferenceDate))"
                guard let savedPreference = try transaction.fetch(FetchDescriptor<FoundationPreferenceRecord>(predicate: #Predicate { $0.key == preferenceKey })).first,
                      let savedDay = try transaction.fetch(FetchDescriptor<FoundationDayRecord>(predicate: #Predicate { $0.key == dayKey })).first else {
                    throw WatchPhoneError.unavailable
                }
                let existingPreference = try context.fetch(FetchDescriptor<FoundationPreferenceRecord>(predicate: #Predicate { $0.key == preferenceKey })).first
                let preference = try existingPreference ?? FoundationPreferenceRecord(key: preferenceKey,
                    profileID: profile.id, sampleData: sample, at: savedPreference.updatedAt)
                if preference.modelContext == nil { context.insert(preference) }
                preference.settingsData = savedPreference.settingsData; preference.quietPeriodsData = savedPreference.quietPeriodsData
                preference.dismissalCountsData = savedPreference.dismissalCountsData; preference.reservationsData = savedPreference.reservationsData
                preference.nudgesEnabled = savedPreference.nudgesEnabled; preference.confirmedMovementNote = savedPreference.confirmedMovementNote
                preference.updatedAt = savedPreference.updatedAt
                let existingDay = try context.fetch(FetchDescriptor<FoundationDayRecord>(predicate: #Predicate { $0.key == dayKey })).first
                let state = try JSONDecoder().decode(FoundationDayState.self, from: savedDay.stateData)
                let day = try existingDay ?? FoundationDayRecord(key: dayKey, profileID: profile.id,
                    sampleData: sample, state: state, at: savedDay.updatedAt)
                if day.modelContext == nil { context.insert(day) }
                day.stateData = savedDay.stateData; day.updatedAt = savedDay.updatedAt
                try context.save()
                foundations.load(profile: profile, sample: sample, environment: environment, context: context)
            case .logMovement, .savedMealHandoff: break
            }
        } catch {
            // The atomic Watch receipt/mutation is already durable. Disable stale controls until refreshed.
            plans.hasLoaded = false
            foundations.clearLoadedValues()
            message = "The Watch change was saved, but the phone view needs reopening before another action."
            throw error
        }
    }

    func loadHandoff(profile: ProfileRecord, sample: Bool, environment: AppEnvironment, context: ModelContext) throws {
        guard handoff == nil else { return }
        let profileID = profile.id
        let rows = try context.fetch(FetchDescriptor<WatchMealHandoffRecord>(
            predicate: #Predicate { $0.profileID == profileID && $0.sampleData == sample && $0.consumedAt == nil }))
        let saved = try context.fetch(FetchDescriptor<FoodCorrectionRecord>(
            predicate: #Predicate { $0.profileID == profileID && $0.sampleData == sample }))
        for row in rows.sorted(by: { $0.id < $1.id }) where environment.calendar.isDate(row.day, inSameDayAs: environment.now) {
            let correction = try saved.map { try JSONDecoder().decode(FoodSavedCorrection.self, from: $0.correctionData) }
                .first { $0.id.uuidString == row.correctionID }
            guard let correction else { continue }
            handoff = WatchMealRoute(id: row.id, title: profile.lowDataMode ? "Saved dish" : correction.candidate.dishName,
                observedAt: correction.candidate.ingredients?.checkedAt ?? correction.confirmedAt)
            break
        }
    }

    func dismissHandoff(id: String, profile: ProfileRecord, sample: Bool, environment: AppEnvironment, context: ModelContext) {
        guard !DataDeletionGate.shared.isBlocked, context.autosaveEnabled else { return }
        let transaction = ModelContext(context.container)
        transaction.autosaveEnabled = false
        do {
            let row = try transaction.fetch(FetchDescriptor<WatchMealHandoffRecord>(predicate: #Predicate { $0.id == id })).first
            guard let row, row.profileID == profile.id, row.sampleData == sample else { return }
            row.consumedAt = environment.now
            try transaction.save()
            handoff = nil
        } catch {
            transaction.rollback()
            message = "The saved dish was not changed. Its handoff may appear again when Steady reopens."
        }
    }
}
