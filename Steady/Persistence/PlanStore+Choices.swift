import Foundation
import SteadyCore
import SwiftData

extension PlanStore {
    func choose(_ option: AlternativeOption, from options: AlternativeSet, source: PlanItem,
                profile: ProfileRecord, sample: Bool, environment: AppEnvironment,
                context: ModelContext) async -> Bool {
        guard !isWorking else { return false }
        isWorking = true; defer { isWorking = false }
        guard validateForMutation(source, profile: profile, sample: sample, environment: environment) else { return false }
        guard await refreshSafety(profile: profile, sample: sample, environment: environment) else { return false }
        guard validateForMutation(source, profile: profile, sample: sample, environment: environment) else { return false }
        do {
            let state = AlternativeChoiceState(plan: source)
            let event = AlternativeChoiceEvent(id: UUID().uuidString, at: environment.now, action: .choose(optionID: option.id))
            let result = try AlternativeChoiceReducer.apply(event, to: state, options: options, safetyFlags: safetyFlags)
            try persist(result.plan, original: source, selected: option, action: "choose", barrier: options.barrier,
                        profile: profile, sample: sample, environment: environment, context: context)
            message = "Your chosen plan is saved."
            return true
        } catch { return fail(error, context: context) }
    }

    func act(_ action: AlternativeChoiceAction, source: PlanItem, profile: ProfileRecord, sample: Bool,
             environment: AppEnvironment, context: ModelContext) async -> Bool {
        guard !isWorking else { return false }
        guard plan?.status != .completed && plan?.status != .intentionallyRested else {
            failure = "This plan is already finished. Your saved choice stays in place."
            return false
        }
        isWorking = true; defer { isWorking = false }
        guard validateForMutation(source, profile: profile, sample: sample, environment: environment, allowSafetyRest: true) else { return false }
        if case .restOnPurpose = action {} else {
            guard await refreshSafety(profile: profile, sample: sample, environment: environment) else { return false }
        }
        guard validateForMutation(source, profile: profile, sample: sample, environment: environment, allowSafetyRest: true) else { return false }
        do {
            let event = AlternativeChoiceEvent(id: UUID().uuidString, at: environment.now, action: action)
            let result = try AlternativeChoiceReducer.apply(event, to: AlternativeChoiceState(plan: source), safetyFlags: safetyFlags)
            let label: String
            switch action {
            case .restOnPurpose: label = "rest"
            case .later: label = "later"
            case .complete: label = "complete"
            case .choose: return false
            }
            try persist(result.plan, original: originalPlan ?? source, selected: selectedOption, action: label,
                        barrier: nil, profile: profile, sample: sample, environment: environment, context: context)
            message = label == "rest" ? "Rest on purpose is saved." : (label == "later" ? "Saved for later, without a Calendar event." : "Completion saved.")
            return true
        } catch { return fail(error, context: context) }
    }

    func start(_ source: PlanItem, profile: ProfileRecord, sample: Bool,
               environment: AppEnvironment, context: ModelContext) async {
        guard !isWorking, record?.startedAt == nil, source.status != .completed,
              source.status != .intentionallyRested else { return }
        isWorking = true; defer { isWorking = false }
        guard validateForMutation(source, profile: profile, sample: sample, environment: environment) else { return }
        guard await refreshSafety(profile: profile, sample: sample, environment: environment) else { return }
        guard validateForMutation(source, profile: profile, sample: sample, environment: environment) else { return }
        if !profile.movementsToAvoid.isEmpty, record?.movementNoteAtChoice != profile.movementsToAvoid {
            failure = "Review your current movement restrictions in alternatives before starting."
            return
        }
        if let slot = source.slot, source.status == .deferred, environment.now < slot.start {
            failure = "This plan is saved for a later time. Choose an alternative to replace it now, or start at the saved time."
            return
        }
        do {
            let active = copy(source, status: record?.eventIdentifier == nil ? .proposed : .scheduled, slot: source.slot)
            try persist(active, original: originalPlan ?? source, selected: selectedOption, action: "start",
                        barrier: nil, startedAt: environment.now, profile: profile, sample: sample,
                        environment: environment, context: context)
            message = "Started. You can shorten or stop whenever you need."
        } catch { _ = fail(error, context: context) }
    }

}
