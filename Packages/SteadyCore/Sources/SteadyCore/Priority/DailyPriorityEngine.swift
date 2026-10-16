import Foundation

public enum DailyPriorityEngine {
    public static func select(for context: DailyContext) -> DailyPriority {
        let safetyDecision = SafetyGate.evaluate(context.safetyFlags)
        if case .pauseRecommendations(let message) = safetyDecision {
            return safetyPriority(message: message, context: context)
        }

        if let selected = context.userSelectedPriority {
            return selectedPriority(selected, context: context)
        }

        if let match = DailyPriorityRules.firstProtectiveMatch(for: context) {
            return priority(from: match, context: context)
        }

        if healthContextIsMissing(context) {
            if let checkInMatch = DailyPriorityRules.stressCheckInMatch(for: context) {
                return priority(from: checkInMatch, context: context)
            }
            return fallbackPriority(context: context)
        }

        if let match = DailyPriorityRules.firstRemainingMatch(for: context) {
            return priority(from: match, context: context)
        }

        return priority(from: DailyPriorityRules.steadyDay(context), context: context)
    }
}

private extension DailyPriorityEngine {
    static func safetyPriority(message: SafetyMessage, context: DailyContext) -> DailyPriority {
        let kind = PriorityKind.lookAfterYourself
        return DailyPriority(
            kind: kind,
            ruleID: "P0",
            title: message.title,
            explanation: Explanation(
                summary: message.guidance + " " + message.emergencyGuidance
            ),
            planA: PriorityPlanFactory.plan(for: kind, context: context, ruleID: "P0")
        )
    }

    static func selectedPriority(_ kind: PriorityKind, context: DailyContext) -> DailyPriority {
        DailyPriority(
            kind: kind,
            ruleID: "U0",
            title: PriorityExplanation.title(for: kind),
            explanation: PriorityExplanation.userSelection(kind),
            planA: PriorityPlanFactory.plan(for: kind, context: context, ruleID: "U0"),
            chosenByUser: true
        )
    }

    static func fallbackPriority(context: DailyContext) -> DailyPriority {
        let kind = PriorityPlanFactory.priorityKind(for: context.preferredFallbackFocus)
        return DailyPriority(
            kind: kind,
            ruleID: "F0",
            title: PriorityExplanation.title(for: kind),
            explanation: Explanation(
                summary: "Health data is unavailable, so this follows the focus you chose."
            ),
            planA: PriorityPlanFactory.plan(for: kind, context: context, ruleID: "F0"),
            chosenByUser: true
        )
    }

    static func priority(from match: PriorityMatch, context: DailyContext) -> DailyPriority {
        DailyPriority(
            kind: match.kind,
            ruleID: match.ruleID,
            title: match.title,
            explanation: match.explanation,
            planA: match.plan ?? PriorityPlanFactory.plan(
                for: match.kind,
                context: context,
                ruleID: match.ruleID
            )
        )
    }

    static func healthContextIsMissing(_ context: DailyContext) -> Bool {
        context.dataGaps.contains(.healthPermissions)
            || (context.dataGaps.contains(.sleep) && context.dataGaps.contains(.activity))
    }
}
