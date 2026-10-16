import Foundation

public enum Symptom: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case pain
    case fainting
    case chestSymptoms
    case unusualBreathlessness
    case feelingUnwell
}

public enum SafetyFlag: Codable, Equatable, Sendable {
    case userReported(Symptom)
    case healthAlert(kind: String, at: Date)
}

public struct SafetyMessage: Codable, Equatable, Sendable {
    public let title: String
    public let guidance: String
    public let emergencyGuidance: String

    public init(title: String, guidance: String, emergencyGuidance: String) {
        self.title = title
        self.guidance = guidance
        self.emergencyGuidance = emergencyGuidance
    }
}

public enum SafetyDecision: Codable, Equatable, Sendable {
    case clear
    case pauseRecommendations(SafetyMessage)

    public var blocksPerformanceRecommendations: Bool {
        switch self {
        case .clear:
            false
        case .pauseRecommendations:
            true
        }
    }
}
