import Foundation

public struct AlternativeEngine: Sendable {
    public let catalog: AlternativeCatalog

    public init(catalog: AlternativeCatalog = .empty) {
        self.catalog = catalog
    }

    public func alternatives(
        for plan: PlanItem,
        barrier: AlternativeBarrier,
        context: AlternativeContext
    ) -> AlternativeResult {
        // Safety is evaluated before catalog lookup, fallback, and filtering.
        if case .pauseRecommendations(let message) = SafetyGate.evaluate(context.safetyFlags) {
            return .blocked(message)
        }
        if let minutes = context.availableMinutes, minutes < 2 {
            return .unavailable("There is not enough time for two useful options. Later and Rest on purpose are still available.")
        }
        let templates = catalog.version == 1 ? catalog.templates : []
        for template in templates where template.planType == plan.type && template.barriers.contains(barrier) {
            // Never repair a malformed template by silently dropping its claims.
            guard (try? AlternativeValidator.validate(template.options, for: plan.outcome)) != nil else { continue }
            let options = template.options.filter { isEligible($0, plan: plan, barrier: barrier, context: context) }
            if (try? AlternativeValidator.validate(options, for: plan.outcome)) != nil {
                return .options(AlternativeSet(planID: plan.id, barrier: barrier, options: options, source: .catalog))
            }
        }
        let options = AlternativeFallback.options(for: plan, barrier: barrier, context: context)
            .filter { isEligible($0, plan: plan, barrier: barrier, context: context) }
        guard (try? AlternativeValidator.validate(options, for: plan.outcome)) != nil else {
            return .unavailable("No suitable pair of options fits this context. You can choose Later or Rest on purpose.")
        }
        return .options(AlternativeSet(planID: plan.id, barrier: barrier, options: options, source: .fallback))
    }

    private func isEligible(
        _ option: AlternativeOption, plan: PlanItem,
        barrier: AlternativeBarrier, context: AlternativeContext
    ) -> Bool {
        if let minutes = context.availableMinutes, option.minutes > minutes { return false }
        // A shorter alternative never adds time to a timed Plan A.
        if plan.minutes > 0 && option.minutes > plan.minutes { return false }
        if barrier == .noTime && option.minutes > 10 { return false }
        if (context.recoveryStatus == .goEasier || barrier == .lowEnergy || barrier == .sore),
           option.effort == .moderate { return false }
        if barrier == .sore && option.planType == .strength { return false }
        return option.supportedMovementModes.contains(context.movementMode)
            && option.requiredMovements.isDisjoint(with: context.movementsToAvoid)
    }
}
