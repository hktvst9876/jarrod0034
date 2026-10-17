import Foundation

public enum AlternativeChoiceReducer {
    /// Applying a choice changes local values only. `later` never writes or
    /// proposes a Calendar event; the caller separately requests a proposal.
    public static func apply(
        _ event: AlternativeChoiceEvent,
        to state: AlternativeChoiceState,
        options: AlternativeSet? = nil,
        safetyFlags: [SafetyFlag] = []
    ) throws -> AlternativeChoiceState {
        guard !event.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AlternativeChoiceError.emptyEventID
        }
        if state.appliedEventIDs.contains(event.id) { return state }
        guard state.plan.status != .completed && state.plan.status != .intentionallyRested else {
            throw AlternativeChoiceError.planFinished
        }
        let plan: PlanItem
        let selected: AlternativeOption?
        switch event.action {
        case .choose(let optionID):
            guard !SafetyGate.evaluate(safetyFlags).blocksPerformanceRecommendations else {
                throw AlternativeChoiceError.safetyBlocked
            }
            guard let options, options.planID == state.plan.id,
                  (try? AlternativeValidator.validate(options.options, for: state.plan.outcome)) != nil,
                  let option = options.options.first(where: { $0.id == optionID }) else {
                throw AlternativeChoiceError.unknownOrStaleOption
            }
            plan = PlanItem(
                id: state.plan.id, day: state.plan.day, type: option.planType,
                title: option.title,
                outcome: Outcome(id: state.plan.outcome.id, summary: option.benefitKept, parts: option.preserves),
                minutes: option.minutes, slot: nil, status: .proposed, origin: .user
            )
            selected = option
        case .later:
            plan = copying(state.plan, status: .deferred)
            selected = state.selectedOption
        case .restOnPurpose:
            plan = copying(state.plan, status: .intentionallyRested)
            selected = state.selectedOption
        case .complete:
            guard state.plan.status != .deferred else { throw AlternativeChoiceError.cannotCompleteDeferredPlan }
            guard !SafetyGate.evaluate(safetyFlags).blocksPerformanceRecommendations else {
                throw AlternativeChoiceError.safetyBlocked
            }
            plan = copying(state.plan, status: .completed)
            selected = state.selectedOption
        }
        return AlternativeChoiceState(
            plan: plan, selectedOption: selected,
            appliedEventIDs: state.appliedEventIDs.union([event.id])
        )
    }

    private static func copying(_ plan: PlanItem, status: PlanStatus) -> PlanItem {
        PlanItem(
            id: plan.id, day: plan.day, type: plan.type, title: plan.title,
            outcome: plan.outcome, minutes: plan.minutes,
            slot: status == .completed ? plan.slot : nil,
            status: status, origin: plan.origin
        )
    }
}
