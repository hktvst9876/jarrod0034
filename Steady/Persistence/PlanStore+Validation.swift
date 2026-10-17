import Foundation
import SteadyCore

extension PlanStore {
    func currentKey(profile: ProfileRecord, sample: Bool, environment: AppEnvironment) -> String {
        let day = environment.calendar.startOfDay(for: environment.now)
        return "\(profile.id.uuidString)-\(Int(day.timeIntervalSinceReferenceDate))-\(sample)"
    }

    func validateContext(profile: ProfileRecord, sample: Bool, environment: AppEnvironment) throws {
        let key = currentKey(profile: profile, sample: sample, environment: environment)
        guard hasLoaded, loadedKey == key else { throw PlanStoreError.contextChanged }
        if let record {
            guard record.key == key, record.profileID == profile.id,
                  record.sampleData == sample, record.supersededByKey == nil else { throw PlanStoreError.contextChanged }
        }
    }

    func validateSource(_ source: PlanItem, profile: ProfileRecord, sample: Bool,
                        environment: AppEnvironment, allowSafetyRest: Bool = false) throws {
        try validateContext(profile: profile, sample: sample, environment: environment)
        guard let current = plan ?? suggestedPlan else { throw PlanStoreError.contextChanged }
        if allowSafetyRest, safetyMessage != nil, current.id == source.id, source.type == .rest { return }
        guard source == current else { throw PlanStoreError.contextChanged }
    }

    func validateForMutation(_ source: PlanItem, profile: ProfileRecord, sample: Bool,
                             environment: AppEnvironment, allowSafetyRest: Bool = false) -> Bool {
        do {
            try validateSource(source, profile: profile, sample: sample, environment: environment, allowSafetyRest: allowSafetyRest)
            return true
        } catch {
            message = nil
            failure = error.localizedDescription
            return false
        }
    }
}
