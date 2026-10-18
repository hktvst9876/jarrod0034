import Foundation

public enum WatchSnapshotBuilder {
    /// Canonical action text is retained. Priority explanations are reconstructed,
    /// never copied from numerical Health-derived explanation factors.
    public static func make(
        id: String, revision: Int, profileID: UUID, useSampleData: Bool,
        priority: DailyPriority?, plan: PlanItem?, alternatives: AlternativeSet?,
        foundation: FoundationOption?, savedMeals: [WatchSavedMealCard],
        movementKinds: [WatchMovementKind] = [], lowDataMode: Bool,
        safetyBlocked: Bool, clock: any Clock,
        calendar: Calendar = SteadyCalendar.singapore(), lifetime: TimeInterval = 14_400
    ) -> WatchSnapshot {
        let now = clock.now
        let day = calendar.startOfDay(for: now)
        let nextDay = calendar.date(byAdding: .day, value: 1, to: day) ?? now
        let boundedLifetime = lifetime.isFinite ? min(14_400, max(1, lifetime)) : 1
        let activePlan = plan.flatMap { value -> PlanItem? in
            guard calendar.isDate(value.day, inSameDayAs: now) else { return nil }
            return value
        }
        let usableAlternatives: [AlternativeOption]
        if !safetyBlocked, let activePlan, let alternatives,
           activePlan.status != .completed, activePlan.status != .intentionallyRested,
           activePlan.status != .deferred, alternatives.planID == activePlan.id,
           (try? AlternativeValidator.validate(alternatives.options, for: activePlan.outcome)) != nil {
            usableAlternatives = alternatives.options
        } else {
            usableAlternatives = []
        }
        let priorityCard: WatchPriorityCard?
        if safetyBlocked {
            priorityCard = WatchPriorityCard(
                title: "Look after yourself",
                reason: "Pause performance plans and open Steady on iPhone for current safety guidance."
            )
        } else if let priority {
            priorityCard = WatchPriorityCard(
                title: lowDataMode ? "Today's priority" : PriorityExplanation.title(for: priority.kind),
                reason: lowDataMode
                    ? "A practical next action; detailed context stays on iPhone."
                    : "Chosen from the available context and your explicit preferences."
            )
        } else {
            priorityCard = nil
        }
        let planCard = safetyBlocked ? nil : activePlan.map {
            WatchPlanCard(id: $0.id, title: lowDataMode ? lowDataPlanTitle($0.type) : $0.title, minutes: $0.minutes,
                          durationExplanation: "The duration of the current app plan, not a target to exceed.",
                          status: $0.status)
        }
        let foundationCard = safetyBlocked ? nil : foundation.map {
            WatchFoundationCard(
                kind: $0.kind, optionID: $0.id, title: $0.title, minutes: $0.minutes,
                durationExplanation: $0.durationExplanation, reason: $0.reason, steps: $0.steps
            )
        }
        var seenMeals: Set<String> = []
        let meals = savedMeals.filter { seenMeals.insert($0.id).inserted }.prefix(3).enumerated().map { index, meal in
            // A caller cannot carry a nutrition/price claim in the uncertainty label.
            WatchSavedMealCard(id: meal.id, title: lowDataMode ? "Saved dish \(["A", "B", "C"][index])" : meal.title)
        }
        var seenMovement: Set<WatchMovementKind> = []
        return WatchSnapshot(
            id: id, revision: revision, profileID: profileID, useSampleData: useSampleData,
            day: day, createdAt: now, expiresAt: min(nextDay, now.addingTimeInterval(boundedLifetime)),
            lowDataMode: lowDataMode, safetyBlocked: safetyBlocked, priority: priorityCard,
            plan: planCard, alternatives: usableAlternatives.map {
                WatchAlternativeCard(
                    id: $0.id, title: $0.title, minutes: $0.minutes,
                    durationExplanation: "The duration of this canonical alternative, not a completion claim.",
                    effort: $0.effort, benefitKept: $0.benefitKept,
                    tradeoff: $0.tradeoff, steps: $0.steps
                )
            }, foundation: foundationCard, savedMeals: meals,
            movementKinds: safetyBlocked ? [] : movementKinds.filter { seenMovement.insert($0).inserted }
        )
    }

    static func lowDataPlanTitle(_ type: PlanType) -> String {
        switch type {
        case .rest: "Intentional rest"
        case .windDown: "A small wind-down"
        case .walk: "A comfortable walk"
        case .mobility: "Comfortable mobility"
        case .strength: "Your strength plan"
        case .cardio: "Your movement plan"
        case .downtime: "A quiet pause"
        case .planned: "Your chosen plan"
        case .steadyDay: "A steady day"
        }
    }
}
