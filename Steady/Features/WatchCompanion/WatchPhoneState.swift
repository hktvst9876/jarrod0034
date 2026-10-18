import CryptoKit
import Foundation
import SteadyCore
import SwiftData

@MainActor
struct WatchPhoneState {
    let plan: PlanItem?
    let planRecord: PlanRecord?
    let alternatives: AlternativeSet?
    let preferences: FoundationPreferenceRecord?
    let foundationRecord: FoundationDayRecord?
    let foundationState: FoundationDayState
    let foundation: FoundationOption?
    let saved: [FoodSavedCorrection]
    let movementKinds: [WatchMovementKind]
    let safetyFlags: [SafetyFlag]
    let bindingDigest: String

    static func read(profile: ProfileRecord, sample: Bool, today: TodayViewModel, planStore: PlanStore,
                     flags: [SafetyFlag], environment: AppEnvironment, context: ModelContext) throws -> Self {
        try planStore.validateContext(profile: profile, sample: sample, environment: environment)
        guard !planStore.isWorking, !today.isLoading else { throw WatchPhoneError.busy }
        let profileID = profile.id
        let day = environment.calendar.startOfDay(for: environment.now)
        let planKey = planStore.currentKey(profile: profile, sample: sample, environment: environment)
        let planRecord = try context.fetch(FetchDescriptor<PlanRecord>(predicate: #Predicate { $0.key == planKey })).first
        let persistedPlan = try planRecord?.plan()
        guard persistedPlan == planStore.plan, planRecord?.supersededByKey == nil else { throw WatchPhoneError.busy }
        let plan = persistedPlan ?? planStore.suggestedPlan
        let preferenceKey = "\(profileID.uuidString)-\(sample)"
        let foundationKey = "\(preferenceKey)-\(Int(day.timeIntervalSinceReferenceDate))"
        let preferences = try context.fetch(FetchDescriptor<FoundationPreferenceRecord>(predicate: #Predicate { $0.key == preferenceKey })).first
        let foundationRecord = try context.fetch(FetchDescriptor<FoundationDayRecord>(predicate: #Predicate { $0.key == foundationKey })).first
        let settings = try preferences.map { try JSONDecoder().decode(FoundationSettings.self, from: $0.settingsData) } ?? FoundationSettings()
        let previous = try foundationRecord.map { try JSONDecoder().decode(FoundationDayState.self, from: $0.stateData) }
        let foundationState = FoundationReducer.startDay(at: environment.now, settings: settings, previous: previous, calendar: environment.calendar)
        let restrictionsConfirmed = profile.movementsToAvoid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || preferences?.confirmedMovementNote == profile.movementsToAvoid
        let blocked = SafetyGate.evaluate(flags).blocksPerformanceRecommendations
        let alternatives: AlternativeSet?
        if let plan, restrictionsConfirmed, !blocked, planRecord?.pendingCalendarData == nil,
           plan.status != .completed, plan.status != .intentionallyRested {
            var catalog = AlternativeCatalog.empty
            if let url = Bundle.main.url(forResource: "plan-alternatives", withExtension: "json"),
               let data = try? Data(contentsOf: url), let decoded = try? AlternativeCatalogLoader.decode(data) { catalog = decoded }
            let result = AlternativeEngine(catalog: catalog).alternatives(for: plan, barrier: .anotherOption,
                context: AlternativeContext(availableMinutes: today.snapshot?.availability.freeMinutesToday,
                    recoveryStatus: today.snapshot?.recovery.status ?? .normal, movementMode: settings.movementMode,
                    movementsToAvoid: settings.movementsToAvoid, safetyFlags: flags))
            if case .options(let values) = result { alternatives = values } else { alternatives = nil }
        } else { alternatives = nil }
        let foundation = !blocked && restrictionsConfirmed ? foundationState.items.lazy.compactMap { item -> FoundationOption? in
            guard item.status == .available || item.status == .replaced else { return nil }
            return FoundationCatalog.options(for: item.kind, settings: settings, safetyFlags: flags).first { $0.id == item.optionID }
        }.first : nil
        let rows = try context.fetch(FetchDescriptor<FoodCorrectionRecord>(
            predicate: #Predicate { $0.profileID == profileID && $0.sampleData == sample })).sorted { $0.key < $1.key }
        let saved = try rows.map { try JSONDecoder().decode(FoodSavedCorrection.self, from: $0.correctionData) }
        guard zip(rows, saved).allSatisfy({ pair in
            let (row, saved) = pair
            return row.key == "\(profileID.uuidString)-\(sample)-\(saved.candidate.id)"
                && saved.candidate.ingredients?.source.kind == .userSaved
                && saved.candidate.ingredients?.source.recordID == saved.id.uuidString
                && saved.candidate.nutrition == nil && saved.candidate.officialMenu == nil
        }) else { throw WatchPhoneError.unavailable }
        let movementKinds = blocked || !restrictionsConfirmed ? [] : allowedMovement(settings)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let fields: [Data] = [try encoder.encode(profile.domainProfile()), try encoder.encode(profile.movementsToAvoid),
            try encoder.encode(profile.reportedSafetySymptomRawValue), try encoder.encode(profile.reportedSafetySymptomAt),
            try encoder.encode(day), try encoder.encode(sample), try encoder.encode(today.priority?.kind),
            try planFingerprint(plan, encoder: encoder), try alternativesFingerprint(alternatives, encoder: encoder),
            try encoder.encode(today.snapshot?.availability.freeMinutesToday), try encoder.encode(today.snapshot?.recovery.status),
            try encoder.encode(foundationRecord?.stateData), try foundationFingerprint(foundation, encoder: encoder),
            try encoder.encode(preferences?.settingsData), try encoder.encode(preferences?.confirmedMovementNote),
            try encoder.encode(rows.map(\.correctionData)),
            try encoder.encode(blocked), try encoder.encode(movementKinds), try encoder.encode(planRecord?.pendingCalendarData)]
        let digest = SHA256.hash(data: try encoder.encode(fields)).map { String(format: "%02x", $0) }.joined()
        return Self(plan: plan, planRecord: planRecord, alternatives: alternatives, preferences: preferences,
            foundationRecord: foundationRecord, foundationState: foundationState, foundation: foundation,
            saved: saved, movementKinds: movementKinds, safetyFlags: flags, bindingDigest: digest)
    }

    func current(snapshot: WatchSnapshot, profile: ProfileRecord, sample: Bool, environment: AppEnvironment) -> WatchCurrentContext {
        WatchCurrentContext(profileID: profile.id, useSampleData: sample,
            day: environment.calendar.startOfDay(for: environment.now), snapshotID: snapshot.id,
            snapshotRevision: snapshot.revision, lowDataMode: profile.lowDataMode,
            safetyBlocked: SafetyGate.evaluate(safetyFlags).blocksPerformanceRecommendations,
            alternativeOptionIDs: Set(alternatives?.options.map(\.id) ?? []),
            foundationKind: foundation?.kind, foundationOptionID: foundation?.id,
            savedCorrectionIDs: Set(saved.map { $0.id.uuidString }), movementKinds: Set(movementKinds))
    }

    private static func allowedMovement(_ settings: FoundationSettings) -> [WatchMovementKind] {
        var result: [WatchMovementKind] = []
        if settings.movementMode == .standing,
           settings.movementsToAvoid.isDisjoint(with: [.walking, .standing, .lowerBody]) { result.append(.walk) }
        if settings.movementsToAvoid.isEmpty { result.append(.mobility) }
        if settings.movementMode == .wheelchair, !settings.movementsToAvoid.contains(.upperBody) { result.append(.wheelchairMovement) }
        return result
    }

    private static func planFingerprint(_ plan: PlanItem?, encoder: JSONEncoder) throws -> Data {
        guard let plan else { return Data() }
        // Set iteration order is not stable; hash explicit sorted parts rather than re-encoded sets.
        return try encoder.encode([encoder.encode(plan.id), encoder.encode(plan.day), encoder.encode(plan.type),
            encoder.encode(plan.title), encoder.encode(plan.outcome.id), encoder.encode(plan.outcome.summary),
            encoder.encode(plan.outcome.parts.map(\.rawValue).sorted()), encoder.encode(plan.minutes),
            encoder.encode(plan.slot), encoder.encode(plan.status), encoder.encode(plan.origin)])
    }

    private static func alternativesFingerprint(_ value: AlternativeSet?, encoder: JSONEncoder) throws -> Data {
        guard let value else { return Data() }
        let rows = try value.options.map { option in
            try encoder.encode([encoder.encode(option.id), encoder.encode(option.title), encoder.encode(option.minutes),
                encoder.encode(option.effort), encoder.encode(option.benefitKept), encoder.encode(option.tradeoff),
                encoder.encode(option.preserves.map(\.rawValue).sorted()),
                encoder.encode(option.doesNotPreserve.map(\.rawValue).sorted()), encoder.encode(option.steps),
                encoder.encode(option.planType), encoder.encode(option.supportedMovementModes.map(\.rawValue).sorted()),
                encoder.encode(option.requiredMovements.map(\.rawValue).sorted())])
        }
        return try encoder.encode([encoder.encode(value.planID), encoder.encode(value.barrier),
            encoder.encode(value.source), encoder.encode(rows)])
    }

    private static func foundationFingerprint(_ option: FoundationOption?, encoder: JSONEncoder) throws -> Data {
        guard let option else { return Data() }
        return try encoder.encode([encoder.encode(option.id), encoder.encode(option.kind), encoder.encode(option.title),
            encoder.encode(option.minutes), encoder.encode(option.durationExplanation), encoder.encode(option.reason),
            encoder.encode(option.steps), encoder.encode(option.supportedMovementModes.map(\.rawValue).sorted()),
            encoder.encode(option.requiredMovements.map(\.rawValue).sorted())])
    }
}

enum WatchPhoneError: Error { case busy, dailyLimit, unavailable, changed }
