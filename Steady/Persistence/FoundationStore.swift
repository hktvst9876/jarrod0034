import Foundation
import Observation
import SteadyCore
import SwiftData

struct FoundationActionSource: Equatable, Sendable {
    let key: String
    let revision: UUID
    let movementNote: String
}

@MainActor
@Observable
final class FoundationStore {
    @ObservationIgnored let dataRevision = DataDeletionGate.shared.revision
    var dataAccessValid: Bool { !DataDeletionGate.shared.isBlocked && dataRevision == DataDeletionGate.shared.revision }
    var preferenceRecord: FoundationPreferenceRecord?
    var dayRecord: FoundationDayRecord?
    var settings = FoundationSettings()
    var dayState: FoundationDayState?
    var quietPeriods: [NudgeQuietPeriod] = []
    var dismissals: [FoundationKind: Int] = [:]
    var reservations: [NudgeReservation] = []
    var nudgesEnabled = false
    var safetyFlags: [SafetyFlag] = []
    var isWorking = false
    var message: String?
    var failure: String?
    var reminderMessage: String?
    var silentCards: [PlannedNudge] = []
    var openFoundationsRequested = false
    var revision = UUID()
    var loadedKey: String?

    var safetyMessage: SafetyMessage? {
        if case .pauseRecommendations(let value) = SafetyGate.evaluate(safetyFlags) { return value }
        return nil
    }

    func load(profile: ProfileRecord, sample: Bool, environment: AppEnvironment, context: ModelContext) {
        guard dataAccessValid else { clearLoadedValues(); return }
        let day = environment.calendar.startOfDay(for: environment.now)
        let preferenceKey = "\(profile.id.uuidString)-\(sample)"
        let key = "\(preferenceKey)-\(Int(day.timeIntervalSinceReferenceDate))"
        do {
            let preferences = try context.fetch(FetchDescriptor<FoundationPreferenceRecord>(
                predicate: #Predicate { $0.key == preferenceKey })).first
                ?? FoundationPreferenceRecord(key: preferenceKey, profileID: profile.id, sampleData: sample, at: environment.now)
            if preferences.modelContext == nil { context.insert(preferences) }
            let decodedSettings = try JSONDecoder().decode(FoundationSettings.self, from: preferences.settingsData)
            let savedDay = try context.fetch(FetchDescriptor<FoundationDayRecord>(predicate: #Predicate { $0.key == key })).first
            let previous = try savedDay.map { try JSONDecoder().decode(FoundationDayState.self, from: $0.stateData) }
            let state = FoundationReducer.startDay(at: environment.now, settings: decodedSettings, previous: previous, calendar: environment.calendar)
            let record = try savedDay ?? FoundationDayRecord(key: key, profileID: profile.id, sampleData: sample, state: state, at: environment.now)
            if record.modelContext == nil { context.insert(record) }
            // Do not rewrite equivalent Set payloads on refresh: a review fingerprint
            // should change for a real Foundation transition, not JSON array ordering.
            if previous != state { record.stateData = try JSONEncoder().encode(state) }
            try context.save()
            preferenceRecord = preferences
            dayRecord = record
            settings = decodedSettings
            dayState = state
            quietPeriods = try JSONDecoder().decode([NudgeQuietPeriod].self, from: preferences.quietPeriodsData)
            dismissals = try JSONDecoder().decode([FoundationKind: Int].self, from: preferences.dismissalCountsData)
            reservations = try JSONDecoder().decode([NudgeReservation].self, from: preferences.reservationsData)
            nudgesEnabled = preferences.nudgesEnabled
            if loadedKey != key { revision = UUID(); message = nil; safetyFlags = []; silentCards = [] }
            loadedKey = key
            if let at = profile.reportedSafetySymptomAt, environment.calendar.isDate(at, inSameDayAs: environment.now),
               let raw = profile.reportedSafetySymptomRawValue, let symptom = Symptom(rawValue: raw) {
                retainSafety([.userReported(symptom)])
            }
            failure = nil
        } catch {
            context.rollback()
            clearLoadedValues()
            failure = "Could not open saved Foundations. Your records have not been erased. Please try again."
        }
    }

    func source(profile: ProfileRecord) -> FoundationActionSource? {
        guard dataAccessValid else { return nil }
        return loadedKey.map { FoundationActionSource(key: $0, revision: revision, movementNote: profile.movementsToAvoid) }
    }

    func movementPreferencesConfirmed(profile: ProfileRecord) -> Bool {
        profile.movementsToAvoid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || preferenceRecord?.confirmedMovementNote == profile.movementsToAvoid
    }

    func options(for kind: FoundationKind, profile: ProfileRecord) -> [FoundationOption] {
        guard movementPreferencesConfirmed(profile: profile) else { return [] }
        return FoundationCatalog.options(for: kind, settings: settings, safetyFlags: safetyFlags)
    }

    func item(_ kind: FoundationKind) -> FoundationItemState? { dayState?.items.first { $0.kind == kind } }

    func validate(_ source: FoundationActionSource, profile: ProfileRecord, sample: Bool, environment: AppEnvironment) throws {
        guard dataAccessValid, source == self.source(profile: profile), let record = dayRecord,
              record.profileID == profile.id, record.sampleData == sample,
              record.key == loadedKey, environment.calendar.isDate(record.day, inSameDayAs: environment.now) else {
            throw FoundationStoreError.staleSource
        }
    }

    func isCurrent(profile: ProfileRecord, sample: Bool, environment: AppEnvironment) -> Bool {
        guard let source = source(profile: profile) else { return false }
        return (try? validate(source, profile: profile, sample: sample, environment: environment)) != nil
    }

    func reserve(_ values: [NudgeReservation], context: ModelContext) throws {
        guard dataAccessValid, let preferenceRecord else { throw FoundationStoreError.storageUnavailable }
        do {
            let calendar = SteadyCalendar.singapore()
            let earliest = dayRecord.flatMap { calendar.date(byAdding: .day, value: -14, to: $0.day) }
            var result = reservations
            if let earliest { result = reservations.filter { $0.day >= earliest } }
            else { result = reservations }
            for value in values {
                if let old = result.first(where: { $0.id == value.id }) {
                    guard old == value else { throw FoundationStoreError.reservationConflict }
                } else { result.append(value) }
            }
            preferenceRecord.reservationsData = try JSONEncoder().encode(result)
            try context.save()
            reservations = result
        } catch { context.rollback(); throw error }
    }

    func clearLoadedValues() {
        preferenceRecord = nil; dayRecord = nil; dayState = nil; loadedKey = nil
        settings = FoundationSettings(); quietPeriods = []; dismissals = [:]; reservations = []
        nudgesEnabled = false; revision = UUID()
        silentCards = []
    }

    func fail(_ error: Error, profile: ProfileRecord, sample: Bool, environment: AppEnvironment, context: ModelContext) {
        guard dataAccessValid else { clearLoadedValues(); return }
        context.rollback()
        load(profile: profile, sample: sample, environment: environment, context: context)
        message = nil
        failure = error.localizedDescription
    }
}

enum FoundationStoreError: LocalizedError {
    case staleSource, preferencesNeeded, storageUnavailable, reservationConflict
    var errorDescription: String? {
        switch self {
        case .staleSource: "This Foundation changed or belongs to an earlier day or data mode. Refresh and try again."
        case .preferencesNeeded: "Review your movement preferences before using these suggestions."
        case .storageUnavailable: "Foundations could not save this change. Please refresh and try again."
        case .reservationConflict: "A reminder identifier no longer matches its saved time. Reminders remain quiet until refreshed."
        }
    }
}
