import Foundation

enum PriorityExplanation {
    static func duration(_ minutes: Int) -> String {
        let safeMinutes = max(0, minutes)
        let hours = safeMinutes / 60
        let remainingMinutes = safeMinutes % 60

        if hours == 0 { return "\(remainingMinutes) min" }
        if remainingMinutes == 0 { return "\(hours) h" }
        return "\(hours) h \(remainingMinutes) min"
    }

    static func userSelection(_ kind: PriorityKind) -> Explanation {
        Explanation(
            summary: "You chose this as today's priority.",
            factors: [
                ExplanationFactor(
                    label: "Choice",
                    displayValue: title(for: kind),
                    why: "Your choice takes priority unless a safety flag needs attention."
                )
            ]
        )
    }

    static func title(for kind: PriorityKind) -> String {
        switch kind {
        case .lookAfterYourself: "Look after yourself"
        case .protectBedtime: "Protect bedtime"
        case .recover: "Go easier"
        case .keepItSmall: "Keep it small"
        case .strength: "Make room for strength"
        case .getMoving: "Get moving"
        case .lighterDay: "Keep today lighter"
        case .followPlan: "Follow today's plan"
        case .steadyDay: "Have a steady day"
        }
    }
}
