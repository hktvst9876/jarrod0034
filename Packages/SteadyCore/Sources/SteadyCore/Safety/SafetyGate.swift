import Foundation

public enum SafetyGate {
    public static func evaluate(_ flags: [SafetyFlag]) -> SafetyDecision {
        guard let firstFlag = flags.first else { return .clear }

        switch firstFlag {
        case .userReported(.feelingUnwell):
            return .pauseRecommendations(
                SafetyMessage(
                    title: "Look after yourself",
                    guidance: "Rest is the plan today. Contact a campus health centre or GP if you are concerned.",
                    emergencyGuidance: "Call 995 if it becomes an emergency."
                )
            )
        case .userReported:
            return .pauseRecommendations(
                SafetyMessage(
                    title: "Please stop and get checked",
                    guidance: "Skip exercise and contact a campus health centre or GP.",
                    emergencyGuidance: "Call 995 in an emergency."
                )
            )
        case .healthAlert:
            return .pauseRecommendations(
                SafetyMessage(
                    title: "Please stop and get checked",
                    guidance: "A health alert needs attention before any performance suggestion. Contact a GP.",
                    emergencyGuidance: "Call 995 in an emergency."
                )
            )
        }
    }
}
