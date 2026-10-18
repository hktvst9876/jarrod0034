import Foundation

public struct WatchPriorityCard: Codable, Equatable, Sendable {
    public let title: String
    public let reason: String

    public init(title: String, reason: String) {
        self.title = title
        self.reason = reason
    }
}

public struct WatchPlanCard: Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let minutes: Int
    public let durationExplanation: String
    public let status: PlanStatus

    public init(id: String, title: String, minutes: Int, durationExplanation: String, status: PlanStatus) {
        self.id = id
        self.title = title
        self.minutes = minutes
        self.durationExplanation = durationExplanation
        self.status = status
    }
}

public struct WatchAlternativeCard: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let minutes: Int
    public let durationExplanation: String
    public let effort: AlternativeEffort
    public let benefitKept: String
    public let tradeoff: String
    public let steps: [String]

    public init(
        id: String, title: String, minutes: Int, durationExplanation: String,
        effort: AlternativeEffort, benefitKept: String, tradeoff: String, steps: [String]
    ) {
        self.id = id
        self.title = title
        self.minutes = minutes
        self.durationExplanation = durationExplanation
        self.effort = effort
        self.benefitKept = benefitKept
        self.tradeoff = tradeoff
        self.steps = steps
    }
}

public struct WatchFoundationCard: Codable, Equatable, Sendable {
    public let kind: FoundationKind
    public let optionID: String
    public let title: String
    public let minutes: Int?
    public let durationExplanation: String
    public let reason: String
    public let steps: [String]

    public init(
        kind: FoundationKind, optionID: String, title: String, minutes: Int?,
        durationExplanation: String, reason: String, steps: [String]
    ) {
        self.kind = kind
        self.optionID = optionID
        self.title = title
        self.minutes = minutes
        self.durationExplanation = durationExplanation
        self.reason = reason
        self.steps = steps
    }
}

/// A reference to an already-confirmed phone record, not a meal or allergy recommendation.
public struct WatchSavedMealCard: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let uncertainty: String

    public init(
        id: String, title: String,
        uncertainty: String = "Saved prior visit; current ingredients and price need checking."
    ) {
        self.id = id
        self.title = title
        self.uncertainty = uncertainty
    }
}

public enum WatchMovementKind: String, Codable, CaseIterable, Hashable, Sendable {
    case walk, mobility, wheelchairMovement

    /// User-entered retrospective records only. These are not exercise targets.
    public static let allowedMinutes: Set<Int> = [5, 10, 20]
}

/// Minimal phone projection. Never pass HealthKit values, recovery labels, calendar
/// events, location, ingredients, price, or nutrition through this schema.
public struct WatchSnapshot: Identifiable, Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let id: String
    public let revision: Int
    public let profileID: UUID
    public let useSampleData: Bool
    public let day: Date
    public let createdAt: Date
    public let expiresAt: Date
    public let lowDataMode: Bool
    public let safetyBlocked: Bool
    public let priority: WatchPriorityCard?
    public let plan: WatchPlanCard?
    public let alternatives: [WatchAlternativeCard]
    public let foundation: WatchFoundationCard?
    public let savedMeals: [WatchSavedMealCard]
    public let movementKinds: [WatchMovementKind]

    public init(
        schemaVersion: Int = 1, id: String, revision: Int, profileID: UUID,
        useSampleData: Bool, day: Date, createdAt: Date, expiresAt: Date,
        lowDataMode: Bool, safetyBlocked: Bool, priority: WatchPriorityCard?,
        plan: WatchPlanCard?, alternatives: [WatchAlternativeCard],
        foundation: WatchFoundationCard?, savedMeals: [WatchSavedMealCard],
        movementKinds: [WatchMovementKind] = []
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.revision = revision
        self.profileID = profileID
        self.useSampleData = useSampleData
        self.day = day
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.lowDataMode = lowDataMode
        self.safetyBlocked = safetyBlocked
        self.priority = priority
        self.plan = plan
        self.alternatives = alternatives
        self.foundation = foundation
        self.savedMeals = savedMeals
        self.movementKinds = movementKinds
    }
}
