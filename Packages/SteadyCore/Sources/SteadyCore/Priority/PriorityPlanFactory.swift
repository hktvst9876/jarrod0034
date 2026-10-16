import Foundation

enum PriorityPlanFactory {
    static func plan(
        for kind: PriorityKind,
        context: DailyContext,
        ruleID: String
    ) -> PlanItem {
        let details = details(for: kind, context: context)
        let slot = suggestedSlot(for: kind, details: details, context: context)

        return PlanItem(
            id: planID(ruleID: ruleID, date: context.date),
            day: context.date,
            type: details.type,
            title: details.title,
            outcome: details.outcome,
            minutes: details.minutes,
            slot: slot,
            origin: .priorityRule
        )
    }

    static func priorityKind(for focus: WellnessFocus) -> PriorityKind {
        switch focus {
        case .sleep:
            .protectBedtime
        case .movement:
            .getMoving
        case .strength:
            .strength
        case .energy:
            .keepItSmall
        case .stress:
            .lighterDay
        case .general:
            .steadyDay
        }
    }
}

private extension PriorityPlanFactory {
    struct PlanDetails {
        let type: PlanType
        let title: String
        let minutes: Int
        let outcome: Outcome
    }

    static func details(for kind: PriorityKind, context: DailyContext) -> PlanDetails {
        switch kind {
        case .lookAfterYourself:
            return PlanDetails(
                type: .rest,
                title: "Rest and get checked if needed",
                minutes: 0,
                outcome: outcome("safety", "Make space to look after yourself", [.dailyRoutine])
            )
        case .protectBedtime:
            return PlanDetails(
                type: .windDown,
                title: "Start your wind-down on time",
                minutes: 45,
                outcome: outcome("sleep", "Protect tonight's sleep opportunity", [.sleepOpportunity])
            )
        case .recover:
            return PlanDetails(
                type: .walk,
                title: "Easy walk and gentle mobility",
                minutes: 30,
                outcome: outcome("recovery", "Keep moving without adding much strain", [.gentleMovement])
            )
        case .keepItSmall:
            return PlanDetails(
                type: .walk,
                title: "Take a 10-minute brisk walk",
                minutes: 10,
                outcome: outcome("small-movement", "Keep a useful movement cue", [.gentleMovement, .dailyRoutine])
            )
        case .strength:
            let minutes = context.examMode ? 25 : 45
            let title = context.examMode ? "Do a condensed strength session" : "Do your next strength session"
            return PlanDetails(
                type: .strength,
                title: title,
                minutes: minutes,
                outcome: outcome("strength", "Build strength this week", [.strengthStimulus])
            )
        case .getMoving:
            return PlanDetails(
                type: .walk,
                title: "Walk or do easy cardio",
                minutes: 30,
                outcome: outcome("aerobic", "Add comfortable aerobic movement", [.aerobicMovement])
            )
        case .lighterDay:
            return PlanDetails(
                type: .downtime,
                title: "Walk outside and plan some downtime",
                minutes: 30,
                outcome: outcome("lighter-day", "Keep the day manageable", [.gentleMovement, .stressRelief])
            )
        case .followPlan:
            return PlanDetails(
                type: .planned,
                title: "Follow today's planned item",
                minutes: context.plannedToday?.minutes ?? 0,
                outcome: context.plannedToday?.outcome
                    ?? outcome("planned", "Follow the plan you chose", [.dailyRoutine])
            )
        case .steadyDay:
            return PlanDetails(
                type: .steadyDay,
                title: "Keep a normal steady day",
                minutes: 0,
                outcome: outcome(
                    "steady",
                    "Support the basics without adding pressure",
                    [.dailyRoutine, .nourishment, .sleepOpportunity]
                )
            )
        }
    }

    static func suggestedSlot(
        for kind: PriorityKind,
        details: PlanDetails,
        context: DailyContext
    ) -> FreeSlot? {
        if kind == .protectBedtime,
           let bedtimePlan = context.sleep.bedtimePlan {
            let end = bedtimePlan.windDownTime.addingTimeInterval(Double(details.minutes * 60))
            return FreeSlot(
                start: bedtimePlan.windDownTime,
                end: end,
                travelAllowanceMinutes: 0,
                confidence: .calendarDerived
            )
        }

        if kind == .followPlan {
            return context.plannedToday?.slot
        }

        return FreeSlotFinder.bestFittingSlot(
            in: context.availability.freeSlots,
            durationMinutes: details.minutes,
            preferredPeriod: context.preferredWorkoutPeriod
        )
    }

    static func outcome(_ id: String, _ summary: String, _ parts: Set<OutcomePart>) -> Outcome {
        Outcome(id: id, summary: summary, parts: parts)
    }

    static func planID(ruleID: String, date: Date) -> String {
        let timestamp = Int(date.timeIntervalSinceReferenceDate.rounded(.down))
        return "priority-\(ruleID)-\(timestamp)"
    }
}
