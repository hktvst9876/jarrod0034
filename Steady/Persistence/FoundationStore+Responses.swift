import Foundation
import SteadyCore
import SwiftData

extension FoundationStore {
    /// Called only on the main actor after loading the matching profile/day.
    /// Returning false keeps the inbox entry for a later storage retry.
    func handleNotificationResponse(_ response: FoundationNotificationResponse, profile: ProfileRecord, sample: Bool,
                                    environment: AppEnvironment, context: ModelContext) async -> Bool {
        guard dataAccessValid, (response.privacyRevision ?? 0) == dataRevision else { return true }
        guard !sample, response.profileID == profile.id else { return true }
        guard isCurrent(profile: profile, sample: sample, environment: environment),
              let source = source(profile: profile), let state = dayState else { return false }
        do {
            if try hasResponse(response.id, context: context) { return true }
            let age = environment.now.timeIntervalSince(response.at)
            let dayAge = environment.now.timeIntervalSince(response.day)
            guard age.isFinite, age >= -60, age <= 14 * 86_400,
                  dayAge.isFinite, dayAge >= 0, dayAge <= 15 * 86_400,
                  reservations.contains(where: { $0.id == response.requestID && $0.kind == response.kind
                      && environment.calendar.isDate($0.day, inSameDayAs: response.day) }) else {
                return try recordIgnored(response, profile: profile, environment: environment, context: context)
            }
            switch response.action {
            case .disable:
                return await act(.disable, kind: response.kind, source: source, profile: profile, sample: false,
                                 environment: environment, context: context, eventID: response.id)
            case .dismiss:
                var counts = dismissals
                counts[response.kind] = min(4, max(0, counts[response.kind] ?? 0) + 1)
                try commit(state, counts: counts, eventID: response.id, kind: response.kind, action: "dismiss",
                           profile: profile, sample: false, environment: environment, context: context)
                return true
            case .open:
                try commit(state, counts: dismissals, eventID: response.id, kind: response.kind, action: "open",
                           profile: profile, sample: false, environment: environment, context: context)
                openFoundationsRequested = true
                return true
            case .done, .snooze:
                guard environment.calendar.isDate(response.day, inSameDayAs: environment.now),
                      let item = item(response.kind), item.status != .done, item.status != .disabled,
                      let option = currentOption(for: response.kind, profile: profile), response.optionID == option.id else {
                    return try recordIgnored(response, profile: profile, environment: environment, context: context)
                }
                await refreshSafety(profile: profile, sample: false, environment: environment)
                try validate(source, profile: profile, sample: false, environment: environment)
                guard safetyMessage == nil else {
                    return try recordIgnored(response, profile: profile, environment: environment, context: context)
                }
                let action: FoundationAction
                if response.action == .done { action = .done }
                else {
                    let until = environment.now.addingTimeInterval(15 * 60)
                    guard environment.calendar.isDate(until, inSameDayAs: environment.now) else {
                        return try recordIgnored(response, profile: profile, environment: environment, context: context)
                    }
                    action = .snooze(until: until)
                }
                return await act(action, kind: response.kind, source: source, profile: profile, sample: false,
                                 environment: environment, context: context, eventID: response.id)
            }
        } catch {
            fail(error, profile: profile, sample: false, environment: environment, context: context)
            return false
        }
    }

    func currentOption(for kind: FoundationKind, profile: ProfileRecord) -> FoundationOption? {
        let values = options(for: kind, profile: profile)
        if let id = item(kind)?.optionID { return values.first { $0.id == id } }
        return values.first
    }

    func recordIgnored(_ response: FoundationNotificationResponse, profile: ProfileRecord,
                       environment: AppEnvironment, context: ModelContext) throws -> Bool {
        guard dataAccessValid else { throw FoundationStoreError.staleSource }
        context.insert(FoundationResponseRecord(id: response.id, profileID: profile.id, sampleData: false,
                       day: response.day, kind: response.kind, action: "ignored-stale-response", at: environment.now))
        try context.save()
        message = "This older reminder was not applied. Review your current Foundations."
        return true
    }
}
