import Foundation

enum AlternativeFallback {
    static func options(
        for plan: PlanItem, barrier: AlternativeBarrier, context: AlternativeContext
    ) -> [AlternativeOption] {
        let planLimit = plan.minutes > 0 ? plan.minutes : 10
        let barrierLimit = barrier == .noTime ? 10 : planLimit
        let maximum = min(context.availableMinutes ?? planLimit, planLimit, barrierLimit)
        guard maximum >= 2 else { return [] }
        let easier = context.recoveryStatus == .goEasier || barrier == .lowEnergy || barrier == .sore
        let candidates: [(AlternativeEffort, Int)] = easier || maximum < 3
            ? [(.minimal, 1), (.light, min(5, maximum))]
            : [(.minimal, 1), (.light, min(5, maximum)), (.moderate, min(10, maximum))]
        return candidates.map { effort, minutes in
            let action = action(for: plan.type, effort: effort, context: context)
            let preserved = plan.outcome.parts.intersection(action.parts)
            let lost = plan.outcome.parts.subtracting(preserved)
            return AlternativeOption(
                id: "fallback-\(plan.type.rawValue)-\(barrier.rawValue)-\(effort.rawValue)",
                title: action.title, minutes: minutes, effort: effort,
                benefitKept: benefit(preserved),
                tradeoff: tradeoff(lost, effort: effort),
                preserves: preserved, doesNotPreserve: lost,
                steps: action.steps, planType: action.type,
                supportedMovementModes: [context.movementMode], requiredMovements: action.movements
            )
        }
    }

    private struct Action {
        let title: String
        let type: PlanType
        let parts: Set<OutcomePart>
        let steps: [String]
        let movements: Set<AlternativeMovement>

        init(_ title: String, _ type: PlanType, _ parts: Set<OutcomePart>, _ steps: [String], _ movements: Set<AlternativeMovement> = []) {
            self.title = title
            self.type = type
            self.parts = parts
            self.steps = steps
            self.movements = movements
        }
    }

    private static func action(
        for type: PlanType, effort: AlternativeEffort, context: AlternativeContext
    ) -> Action {
        if effort == .minimal {
            if type == .windDown {
                return Action("Put the phone aside and settle", .windDown, [.sleepOpportunity], [
                    "Put the phone out of reach if that suits you.",
                    "Leave the next moment free to settle; sleep is not guaranteed."
                ])
            }
            return Action("Take a quiet pause", .downtime, [.stressRelief], [
                "Choose a comfortable position.", "Pause without adding a task; stop whenever you wish."
            ])
        }
        switch type {
        case .windDown:
            return Action(
                effort == .light ? "Keep a simple wind-down" : "Prepare and wind down",
                .windDown, [.sleepOpportunity, .dailyRoutine],
                effort == .light
                    ? ["Set aside the current task.", "Choose one familiar, quiet activity before bed."]
                    : ["Prepare what you need for tomorrow.", "Set the phone aside and choose a quiet activity before bed."]
            )
        case .walk, .mobility, .cardio, .strength:
            return movementAction(for: type, effort: effort, context: context)
        case .rest, .downtime:
            return Action(
                effort == .light ? "Make a little quiet space" : "Set up a quiet reset",
                .downtime, [.stressRelief, .dailyRoutine],
                effort == .light
                    ? ["Set a task aside.", "Take a comfortable break with no completion target."]
                    : ["Clear one small interruption if you want to.", "Choose a comfortable place and leave time for a quiet break."]
            )
        case .planned, .steadyDay:
            // An arbitrary calendar plan may be a meal, work, or something else.
            // Do not invent a replacement or claim its nourishment outcome.
            return Action(
                effort == .light ? "Keep one small routine cue" : "Prepare the next small step",
                .planned, [.dailyRoutine],
                effort == .light
                    ? ["Choose one familiar, manageable preparation step.", "Do only that step; the original activity remains optional."]
                    : ["Identify one small step from your original plan.", "Prepare what you need and do that step if it still fits."]
            )
        }
    }

    private static func movementAction(
        for type: PlanType, effort: AlternativeEffort, context: AlternativeContext
    ) -> Action {
        let available: Set<AlternativeMovement> = context.movementMode == .standing
            ? [.upperBody, .lowerBody, .standing, .walking] : [.upperBody]
        let allowed = available.subtracting(context.movementsToAvoid)
        guard allowed.contains(.upperBody) || allowed.contains(.lowerBody) else {
            return Action(
                effort == .light ? "Prepare a comfortable quiet break" : "Set up a little quiet space",
                .downtime, [.stressRelief, .dailyRoutine],
                effort == .light
                    ? ["Choose a comfortable position without using movements you avoid.", "Take a quiet break; this does not replace training."]
                    : ["Set aside one interruption without using movements you avoid.", "Choose a comfortable quiet activity and leave a little time for it; this does not replace training."]
            )
        }
        if effort == .moderate && type == .strength && context.movementMode == .standing
            && allowed.contains(.upperBody) && allowed.contains(.lowerBody) && allowed.contains(.standing) {
            return Action("Do a shorter familiar strength routine", .strength, [.strengthStimulus], [
                "Use movements and loads already comfortable in your usual routine.",
                "Do one easy familiar set, with breaks; add no load or repetitions to make up time.",
                "Stop if anything hurts or feels unusual."
            ], [.upperBody, .lowerBody, .standing])
        }
        if effort == .moderate && (type == .walk || type == .cardio)
            && context.movementMode == .standing && allowed.contains(.walking) && allowed.contains(.standing)
            && allowed.contains(.lowerBody) {
            return Action("Take a short comfortable indoor walk", .walk, [.gentleMovement, .aerobicMovement], [
                "Use a familiar, accessible indoor route.",
                "Walk at a comfortable pace with breaks; stop for pain or unusual symptoms."
            ], [.walking, .standing, .lowerBody])
        }
        let movement: AlternativeMovement = allowed.contains(.upperBody) ? .upperBody
            : allowed.contains(.lowerBody) ? .lowerBody : .standing
        let position = context.movementMode == .standing ? "a comfortable position" : "your usual seated position"
        return Action(
            effort == .light ? "Try gentle comfortable mobility" : "Try a familiar mobility sequence",
            .mobility, [.gentleMovement], [
                "Stay in \(position); no transfer or standing is required.",
                movement == .upperBody
                    ? (effort == .light ? "Choose one familiar upper-body movement and keep it comfortable."
                        : "Use two or three familiar upper-body movements, with comfortable ranges and breaks.")
                    : (effort == .light ? "Choose one familiar movement you do not avoid and keep it comfortable."
                        : "Use two or three familiar movements you do not avoid, with comfortable ranges and breaks."),
                "Keep the range easy, take breaks, and stop for pain or unusual symptoms."
            ], [movement]
        )
    }

    private static func benefit(_ parts: Set<OutcomePart>) -> String {
        if parts.isEmpty { return "Makes room for a manageable pause; no original outcome part is claimed." }
        return "Keeps: " + parts.map(label).sorted().joined(separator: ", ") + "."
    }

    private static func tradeoff(_ lost: Set<OutcomePart>, effort: AlternativeEffort) -> String {
        let scope = effort == .minimal ? "This is a small pause rather than the full activity."
            : "The full plan's duration and scope are not retained."
        guard !lost.isEmpty else { return scope }
        return "Does not keep: " + lost.map(label).sorted().joined(separator: ", ") + ". " + scope
    }

    private static func label(_ part: OutcomePart) -> String {
        switch part {
        case .sleepOpportunity: "sleep opportunity"
        case .gentleMovement: "gentle movement"
        case .strengthStimulus: "strength stimulus"
        case .aerobicMovement: "aerobic movement"
        case .stressRelief: "space for stress relief"
        case .dailyRoutine: "a routine cue"
        case .nourishment: "nourishment"
        }
    }
}
