import Foundation

struct PriorityMatch {
    let kind: PriorityKind
    let ruleID: String
    let title: String
    let explanation: Explanation
    let plan: PlanItem?

    init(
        kind: PriorityKind,
        ruleID: String,
        explanation: Explanation,
        plan: PlanItem? = nil
    ) {
        self.kind = kind
        self.ruleID = ruleID
        self.title = PriorityExplanation.title(for: kind)
        self.explanation = explanation
        self.plan = plan
    }
}

enum DailyPriorityRules {
    static func firstProtectiveMatch(for context: DailyContext) -> PriorityMatch? {
        protectBedtime(context)
            ?? recover(context)
            ?? keepItSmall(context)
    }

    static func firstRemainingMatch(for context: DailyContext) -> PriorityMatch? {
        strength(context)
            ?? getMoving(context)
            ?? lighterDay(context)
            ?? followPlan(context)
    }

    static func stressCheckInMatch(for context: DailyContext) -> PriorityMatch? {
        lighterDay(context)
    }

    static func steadyDay(_ context: DailyContext) -> PriorityMatch {
        PriorityMatch(
            kind: .steadyDay,
            ruleID: "P8",
            explanation: Explanation(summary: "Nothing is urgent. A normal steady day fits.")
        )
    }
}

private extension DailyPriorityRules {
    static func protectBedtime(_ context: DailyContext) -> PriorityMatch? {
        let lastNightMinutes = context.sleep.lastNight?.asleepMinutes
        let shortNightThreshold = context.examMode ? 60 : 90
        let isShortNight = lastNightMinutes.map {
            $0 < context.sleepNeedMinutes - shortNightThreshold
        } ?? false
        let hasLargeShortfall = context.sleep.shortfall7dMinutes.map { $0 >= 5 * 60 } ?? false
        guard isShortNight || hasLargeShortfall else { return nil }

        if let minutes = lastNightMinutes, isShortNight {
            let displayed = PriorityExplanation.duration(minutes)
            return PriorityMatch(
                kind: .protectBedtime,
                ruleID: "P1",
                explanation: Explanation(
                    summary: "You slept \(displayed). Tonight's bedtime matters most.",
                    factors: [
                        ExplanationFactor(
                            label: "Sleep last night",
                            displayValue: displayed,
                            why: "This is below the sleep opportunity you asked Steady to protect."
                        )
                    ]
                )
            )
        }

        let shortfall = context.sleep.shortfall7dMinutes ?? 0
        let displayed = PriorityExplanation.duration(shortfall)
        return PriorityMatch(
            kind: .protectBedtime,
            ruleID: "P1",
            explanation: Explanation(
                summary: "Your recent sleep shortfall is \(displayed). Protect bedtime tonight.",
                factors: [
                    ExplanationFactor(
                        label: "Seven-day shortfall",
                        displayValue: displayed,
                        why: "It adds only the gap below your sleep need on tracked nights."
                    )
                ]
            )
        )
    }

    static func recover(_ context: DailyContext) -> PriorityMatch? {
        guard context.recovery.status == .goEasier || context.checkIn == .sore else {
            return nil
        }

        let summary: String
        if context.checkIn == .sore {
            summary = "You said you feel sore, so today's plan stays gentle."
        } else {
            summary = context.recovery.reasons.map(\.message).joined(separator: " ")
        }

        return PriorityMatch(
            kind: .recover,
            ruleID: "P2",
            explanation: Explanation(
                summary: summary.isEmpty ? "A few recovery signals suggest going easier today." : summary
            )
        )
    }

    static func keepItSmall(_ context: DailyContext) -> PriorityMatch? {
        let freeMinutes = context.availability.freeMinutesToday
        guard context.checkIn == .shortOnTime || freeMinutes.map({ $0 < 45 }) == true else {
            return nil
        }

        if let freeMinutes {
            return PriorityMatch(
                kind: .keepItSmall,
                ruleID: "P3",
                explanation: Explanation(
                    summary: "Only \(freeMinutes) free minutes fit today. A short walk still counts.",
                    factors: [
                        ExplanationFactor(
                            label: "Free time",
                            displayValue: "\(freeMinutes) min",
                            why: "This comes from today's available gaps, after calendar padding."
                        )
                    ]
                )
            )
        }

        return PriorityMatch(
            kind: .keepItSmall,
            ruleID: "P3",
            explanation: Explanation(summary: "You said time is tight, so the useful version is short.")
        )
    }

    static func strength(_ context: DailyContext) -> PriorityMatch? {
        let remaining = max(0, context.strengthTarget - context.strengthDoneThisWeek)
        let timingCallsForStrength = context.plannedStrengthDay
            || context.daysLeftInWeekIncludingToday <= 2 * remaining
        guard remaining > 0, !context.strengthYesterday, timingCallsForStrength else {
            return nil
        }

        return PriorityMatch(
            kind: .strength,
            ruleID: "P4",
            explanation: Explanation(
                summary: "\(remaining) of \(context.strengthTarget) sessions remain with \(context.daysLeftInWeekIncludingToday) days to go.",
                factors: [
                    ExplanationFactor(
                        label: "Strength sessions left",
                        displayValue: "\(remaining)",
                        why: "This is your weekly target minus completed sessions."
                    ),
                    ExplanationFactor(
                        label: "Days left",
                        displayValue: "\(context.daysLeftInWeekIncludingToday)",
                        why: "Weeks run from Monday through Sunday."
                    )
                ]
            )
        )
    }

    static func getMoving(_ context: DailyContext) -> PriorityMatch? {
        guard let days = context.activity.daysSinceExercise, days >= 2 else { return nil }
        return PriorityMatch(
            kind: .getMoving,
            ruleID: "P5",
            explanation: Explanation(
                summary: "No exercise was logged for \(days) days. Comfortable movement fits today.",
                factors: [
                    ExplanationFactor(
                        label: "Days since exercise",
                        displayValue: "\(days)",
                        why: "This uses your latest available workout record."
                    )
                ]
            )
        )
    }

    static func lighterDay(_ context: DailyContext) -> PriorityMatch? {
        guard context.checkIn == .stressed else { return nil }
        return PriorityMatch(
            kind: .lighterDay,
            ruleID: "P6",
            explanation: Explanation(summary: "You said today feels stressful, so the plan stays light.")
        )
    }

    static func followPlan(_ context: DailyContext) -> PriorityMatch? {
        guard let planned = context.plannedToday else { return nil }
        let plan = context.checkIn == .lowEnergy ? planned.condensed() : planned
        return PriorityMatch(
            kind: .followPlan,
            ruleID: "P7",
            explanation: Explanation(summary: "This item was already planned for today."),
            plan: plan
        )
    }
}
