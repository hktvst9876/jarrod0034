import Foundation

/// A fixed local library, not a treatment plan or a completion target.
public enum FoundationCatalog {
    public static func options(
        for kind: FoundationKind,
        settings: FoundationSettings = FoundationSettings(),
        safetyFlags: [SafetyFlag] = []
    ) -> [FoundationOption] {
        guard !settings.disabledKinds.contains(kind),
              !SafetyGate.evaluate(safetyFlags).blocksPerformanceRecommendations else { return [] }
        return allOptions.filter {
            $0.kind == kind && $0.supportedMovementModes.contains(settings.movementMode)
                && $0.requiredMovements.isDisjoint(with: settings.movementsToAvoid)
        }
    }

    static let allOptions: [FoundationOption] = movementOptions + everydayOptions

    private static let movementOptions: [FoundationOption] = [
        FoundationOption(
            id: "mobility-standing-ankles", kind: .mobility, title: "Comfortable ankle mobility", minutes: 2,
            durationExplanation: "A brief optional starting point; stop sooner whenever you prefer.",
            reason: "A small way to change position after waking, if comfortable.",
            steps: ["Hold a stable support if needed.", "Make small comfortable ankle movements. Stop if anything hurts."],
            supportedMovementModes: [.standing], requiredMovements: [.standing, .lowerBody]
        ),
        FoundationOption(
            id: "mobility-shoulders", kind: .mobility, title: "Comfortable shoulder mobility", minutes: 2,
            durationExplanation: "A brief optional starting point, not a target to push through.",
            reason: "An upper-body alternative that can be done in your usual supported position.",
            steps: ["Use a stable, supported position.", "Try small easy shoulder movements within a comfortable range; stop if painful."],
            requiredMovements: [.upperBody]
        ),
        FoundationOption(
            id: "mobility-hands", kind: .mobility, title: "Easy hands and wrists", minutes: 2,
            durationExplanation: "A short optional pause; less time is fine.",
            reason: "A different gentle upper-body option without standing or walking.",
            steps: ["Rest your forearms comfortably.", "Gently open and close your hands or make small wrist movements; skip discomfort."],
            requiredMovements: [.upperBody]
        ),
        FoundationOption(
            id: "movement-standing", kind: .movementBreak, title: "Change position briefly", minutes: 2,
            durationExplanation: "A brief break from a study position, not an exercise requirement.",
            reason: "A comfortable position change can break up a long block of sitting.",
            steps: ["Save your place in your work.", "Stand with support if comfortable, then return when ready."],
            supportedMovementModes: [.standing], requiredMovements: [.standing, .lowerBody]
        ),
        FoundationOption(
            id: "movement-seated", kind: .movementBreak, title: "Supported movement break", minutes: 2,
            durationExplanation: "An optional short break; stop sooner if you wish.",
            reason: "A seated or wheelchair-friendly way to change what your upper body is doing.",
            steps: ["Stay in your usual safe supported position.", "Try a few comfortable arm or shoulder movements; no transfer or wheelchair propulsion is needed."],
            requiredMovements: [.upperBody]
        ),
        FoundationOption(
            id: "movement-hands", kind: .movementBreak, title: "Give your hands a pause", minutes: 1,
            durationExplanation: "A small interruption, not a minimum dose.",
            reason: "A different upper-body break when standing is not a suitable option.",
            steps: ["Put down the keyboard or phone.", "Relax and gently move your hands only as comfortable."],
            requiredMovements: [.upperBody]
        )
    ]

    private static let everydayOptions: [FoundationOption] = [
        FoundationOption(
            id: "daylight-shade", kind: .daylight, title: "A pause outdoors in shade", minutes: 3,
            durationExplanation: "An optional brief pause, not a prescribed daylight dose.",
            reason: "Morning daylight is an opportunity to step away from indoor work, not a score to earn.",
            steps: ["Choose a safe accessible shaded outdoor spot; stay seated if preferred.",
                    "Never look directly at the sun. Use shade and your usual sun protection, especially in strong UV.",
                    "Skip outdoor time if heat, weather, or access makes it unsuitable."]
        ),
        FoundationOption(
            id: "daylight-shelter", kind: .daylight, title: "A sheltered daylight pause", minutes: 1,
            durationExplanation: "A smaller optional pause; no exposure target is tracked.",
            reason: "A sheltered accessible spot can be more practical than a walk.",
            steps: ["If safe, choose a shaded sheltered outdoor place without needing to walk.",
                    "Face your surroundings, never the sun; use your usual sun protection.",
                    "Stay indoors instead if outdoor conditions are uncomfortable or unsafe."]
        ),
        FoundationOption(
            id: "hydration-meal", kind: .hydration, title: "Water with your meal, if thirsty", minutes: nil,
            durationExplanation: "There is no timer or fixed intake target for this cue.",
            reason: "A meal can be a convenient moment to notice thirst.",
            steps: ["Notice whether you are thirsty and keep water available if useful.",
                    "Drink according to thirst and your own needs. Follow any clinician-provided fluid guidance."]
        ),
        FoundationOption(
            id: "hydration-available", kind: .hydration, title: "Put water within reach", minutes: nil,
            durationExplanation: "This is a practical cue, not a measured drinking task.",
            reason: "Making water accessible leaves the choice of drinking to you.",
            steps: ["Place water where it is easy to reach, if helpful.",
                    "Drink when thirsty; no fixed volume or quota is set. Follow any personal fluid restriction."]
        ),
        FoundationOption(
            id: "reset-quiet", kind: .reset, title: "A quiet preparation pause", minutes: 1,
            durationExplanation: "A small optional pause before demanding work.",
            reason: "A moment to choose the next practical step, not a treatment for stress.",
            steps: ["Set the screen aside if helpful.", "Notice your surroundings and choose one manageable next step."]
        ),
        FoundationOption(
            id: "reset-breathe", kind: .reset, title: "An unforced breathing pause", minutes: 1,
            durationExplanation: "An optional brief pause, with no breath count or hold target.",
            reason: "A quiet alternative before work; it does not diagnose or treat stress.",
            steps: ["Use a comfortable supported position.",
                    "Let breathing stay easy and natural. Do not force deep breaths or hold your breath; stop if uncomfortable."]
        ),
        FoundationOption(
            id: "winddown-smallest", kind: .windDown, title: "The smallest useful wind-down", minutes: 1,
            durationExplanation: "A small starting point; an elaborate routine is not required.",
            reason: "Making the next bedtime step easier matters more than completing a ritual.",
            steps: ["Put one distracting item aside if useful.", "Prepare one thing for sleep, then choose whether to continue or rest."]
        ),
        FoundationOption(
            id: "winddown-prepare", kind: .windDown, title: "Prepare a quiet stopping point", minutes: 2,
            durationExplanation: "An optional short transition, not a required routine length.",
            reason: "A simple stopping point can make it easier to leave tomorrow's tasks for tomorrow.",
            steps: ["Save your place or write a short note for tomorrow.", "Close the current task and make your sleep space comfortable if possible."]
        )
    ]
}
