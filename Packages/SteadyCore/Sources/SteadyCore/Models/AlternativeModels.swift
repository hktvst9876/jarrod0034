import Foundation

public enum AlternativeBarrier: String, Codable, CaseIterable, Hashable, Sendable {
    case anotherOption, lowEnergy, sore, stressed, noTime, badWeather, homeLate
    case noKitchen, socialPlans, lowBudget, lateHunger, deliveryPreference
    case sweetDrinkPreference, phoneUseInBed
}

public enum AlternativeEffort: String, Codable, CaseIterable, Hashable, Sendable {
    case minimal, light, moderate
}

public enum AlternativeMovementMode: String, Codable, CaseIterable, Hashable, Sendable {
    case standing, seated, wheelchair
}

public enum AlternativeMovement: String, Codable, CaseIterable, Hashable, Sendable {
    case walking, standing, upperBody, lowerBody
}

/// Only explicitly supplied context is used. A favorable recovery label never
/// increases the maximum effort or duration of an option.
public struct AlternativeContext: Codable, Equatable, Sendable {
    public let availableMinutes: Int?
    public let recoveryStatus: RecoveryStatus
    public let movementMode: AlternativeMovementMode
    public let movementsToAvoid: Set<AlternativeMovement>
    public let safetyFlags: [SafetyFlag]

    public init(
        availableMinutes: Int? = nil,
        recoveryStatus: RecoveryStatus = .normal,
        movementMode: AlternativeMovementMode = .standing,
        movementsToAvoid: Set<AlternativeMovement> = [],
        safetyFlags: [SafetyFlag] = []
    ) {
        self.availableMinutes = availableMinutes.map { max(0, $0) }
        self.recoveryStatus = recoveryStatus
        self.movementMode = movementMode
        self.movementsToAvoid = movementsToAvoid
        self.safetyFlags = safetyFlags
    }
}

public struct AlternativeOption: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let minutes: Int
    public let effort: AlternativeEffort
    public let benefitKept: String
    public let tradeoff: String
    public let preserves: Set<OutcomePart>
    public let doesNotPreserve: Set<OutcomePart>
    public let steps: [String]
    public let planType: PlanType
    public let supportedMovementModes: Set<AlternativeMovementMode>
    public let requiredMovements: Set<AlternativeMovement>

    public init(
        id: String, title: String, minutes: Int, effort: AlternativeEffort,
        benefitKept: String, tradeoff: String, preserves: Set<OutcomePart>,
        doesNotPreserve: Set<OutcomePart>, steps: [String], planType: PlanType,
        supportedMovementModes: Set<AlternativeMovementMode> = Set(AlternativeMovementMode.allCases),
        requiredMovements: Set<AlternativeMovement> = []
    ) {
        self.id = id
        self.title = title
        self.minutes = minutes
        self.effort = effort
        self.benefitKept = benefitKept
        self.tradeoff = tradeoff
        self.preserves = preserves
        self.doesNotPreserve = doesNotPreserve
        self.steps = steps
        self.planType = planType
        self.supportedMovementModes = supportedMovementModes
        self.requiredMovements = requiredMovements
    }
}

public enum AlternativeSource: String, Codable, Equatable, Sendable {
    case catalog, fallback
}

public struct AlternativeSet: Codable, Equatable, Sendable {
    public let planID: String
    public let barrier: AlternativeBarrier
    public let options: [AlternativeOption]
    public let source: AlternativeSource

    public init(planID: String, barrier: AlternativeBarrier, options: [AlternativeOption], source: AlternativeSource) {
        self.planID = planID
        self.barrier = barrier
        self.options = options
        self.source = source
    }
}

public enum AlternativeResult: Codable, Equatable, Sendable {
    case options(AlternativeSet)
    case blocked(SafetyMessage)
    case unavailable(String)
}
