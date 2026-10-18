import Foundation
import SteadyCore
import SwiftData

extension FoundationStore {
    func act(_ action: FoundationAction, kind: FoundationKind, source: FoundationActionSource,
             profile: ProfileRecord, sample: Bool, environment: AppEnvironment,
             additionalSafety: [SafetyFlag] = [], context: ModelContext, eventID: String = UUID().uuidString) async -> Bool {
        guard !isWorking else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            try validate(source, profile: profile, sample: sample, environment: environment)
            if try hasResponse(eventID, context: context) { return true }
            switch action {
            case .done, .replace, .snooze, .resume:
                guard movementPreferencesConfirmed(profile: profile) else { throw FoundationStoreError.preferencesNeeded }
                await refreshSafety(profile: profile, sample: sample, environment: environment, additional: additionalSafety)
                try validate(source, profile: profile, sample: sample, environment: environment)
            case .disable, .enable: break
            }
            guard let state = dayState else { throw FoundationStoreError.storageUnavailable }
            let event = FoundationEvent(id: eventID, day: state.day, kind: kind, action: action)
            let value = try FoundationReducer.apply(event, to: state, now: environment.now, calendar: environment.calendar, safetyFlags: safetyFlags)
            var counts = dismissals
            if action == .done { counts[kind] = 0 }
            try commit(value, counts: counts, eventID: eventID, kind: kind, action: actionName(action),
                       profile: profile, sample: sample, environment: environment, context: context)
            message = "Saved on this device."
            return true
        } catch {
            fail(error, profile: profile, sample: sample, environment: environment, context: context)
            return false
        }
    }

    func refreshSafety(profile: ProfileRecord, sample: Bool, environment: AppEnvironment, additional: [SafetyFlag] = []) async {
        guard dataAccessValid else { return }
        let day = environment.calendar.startOfDay(for: environment.now)
        let key = loadedKey
        let flags = (try? await environment.health(useSampleData: sample).safetyFlags(on: environment.now, calendar: environment.calendar)) ?? safetyFlags
        guard dataAccessValid, key == loadedKey, day == environment.calendar.startOfDay(for: environment.now) else { return }
        var reported: [SafetyFlag] = []
        if let at = profile.reportedSafetySymptomAt, environment.calendar.isDate(at, inSameDayAs: environment.now),
           let raw = profile.reportedSafetySymptomRawValue, let symptom = Symptom(rawValue: raw) { reported = [.userReported(symptom)] }
        retainSafety(flags + reported + additional)
    }

    func retainSafety(_ flags: [SafetyFlag]) {
        guard dataAccessValid else { return }
        for flag in flags where !safetyFlags.contains(flag) { safetyFlags.append(flag) }
    }

    func savePreferences(mode: AlternativeMovementMode, avoids: Set<AlternativeMovement>, quiet: [NudgeQuietPeriod],
                         source: FoundationActionSource, profile: ProfileRecord, sample: Bool,
                         environment: AppEnvironment, context: ModelContext) -> Bool {
        do {
            try validate(source, profile: profile, sample: sample, environment: environment)
            guard let preferenceRecord, let state = dayState else { throw FoundationStoreError.storageUnavailable }
            let value = FoundationSettings(disabledKinds: settings.disabledKinds, movementMode: mode, movementsToAvoid: avoids)
            let reconciled = FoundationReducer.reconcile(settings: value, state: state, now: environment.now, calendar: environment.calendar)
            preferenceRecord.confirmedMovementNote = profile.movementsToAvoid
            preferenceRecord.quietPeriodsData = try JSONEncoder().encode(quiet)
            try commit(reconciled, counts: dismissals, eventID: UUID().uuidString, kind: .mobility, action: "preferences",
                       profile: profile, sample: sample, environment: environment, context: context)
            quietPeriods = quiet
            message = "Foundation preferences saved."
            return true
        } catch { fail(error, profile: profile, sample: sample, environment: environment, context: context); return false }
    }

    func setNudgesEnabled(_ enabled: Bool, source: FoundationActionSource, profile: ProfileRecord, sample: Bool,
                          environment: AppEnvironment, context: ModelContext) -> Bool {
        do {
            try validate(source, profile: profile, sample: sample, environment: environment)
            guard let preferenceRecord else { throw FoundationStoreError.storageUnavailable }
            preferenceRecord.nudgesEnabled = enabled
            preferenceRecord.updatedAt = environment.now
            try context.save()
            nudgesEnabled = enabled
            revision = UUID()
            return true
        } catch { fail(error, profile: profile, sample: sample, environment: environment, context: context); return false }
    }

    func resumeReminders(kind: FoundationKind, source: FoundationActionSource, profile: ProfileRecord, sample: Bool,
                         environment: AppEnvironment, context: ModelContext) -> Bool {
        do {
            try validate(source, profile: profile, sample: sample, environment: environment)
            guard let state = dayState else { throw FoundationStoreError.storageUnavailable }
            var counts = dismissals; counts[kind] = 0
            try commit(state, counts: counts, eventID: UUID().uuidString, kind: kind, action: "resume-reminders",
                       profile: profile, sample: sample, environment: environment, context: context)
            message = "Reminders for this Foundation can be considered again."
            return true
        } catch { fail(error, profile: profile, sample: sample, environment: environment, context: context); return false }
    }

    func commit(_ state: FoundationDayState, counts: [FoundationKind: Int], eventID: String, kind: FoundationKind, action: String,
                profile: ProfileRecord, sample: Bool, environment: AppEnvironment, context: ModelContext) throws {
        guard dataAccessValid, let preferenceRecord, let dayRecord else { throw FoundationStoreError.storageUnavailable }
        dayRecord.stateData = try JSONEncoder().encode(state)
        dayRecord.updatedAt = environment.now
        preferenceRecord.settingsData = try JSONEncoder().encode(state.settings)
        preferenceRecord.dismissalCountsData = try JSONEncoder().encode(counts)
        preferenceRecord.updatedAt = environment.now
        context.insert(FoundationResponseRecord(id: eventID, profileID: profile.id, sampleData: sample,
                       day: state.day, kind: kind, action: action, at: environment.now))
        try context.save()
        dayState = state; settings = state.settings; dismissals = counts; revision = UUID(); failure = nil; silentCards = []
    }

    func hasResponse(_ id: String, context: ModelContext) throws -> Bool {
        guard dataAccessValid else { throw FoundationStoreError.staleSource }
        let values = try context.fetch(FetchDescriptor<FoundationResponseRecord>(predicate: #Predicate { $0.id == id }))
        return !values.isEmpty
    }

    func actionName(_ action: FoundationAction) -> String {
        switch action {
        case .done: "done"
        case .replace: "replace"
        case .snooze: "snooze"
        case .disable: "disable"
        case .enable: "enable"
        case .resume: "resume"
        }
    }
}
