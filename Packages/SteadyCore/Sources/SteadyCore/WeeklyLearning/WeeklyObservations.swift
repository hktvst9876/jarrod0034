import Foundation

public struct WeeklyPlanObservation: Codable, Equatable, Sendable {
    public let id: String
    public let day: Date
    public let completed: Bool
    public let changed: Bool

    public init(id: String, day: Date, completed: Bool, changed: Bool) {
        self.id = id
        self.day = day
        self.completed = completed
        self.changed = changed
    }
}

public enum WeeklyChoiceKind: String, Codable, Equatable, Sendable {
    case choose, later, rest, complete
}

public struct WeeklyChoiceObservation: Codable, Equatable, Sendable {
    public let id: String
    public let at: Date
    public let planID: String
    public let kind: WeeklyChoiceKind
    public let optionID: String?

    public init(id: String, at: Date, planID: String, kind: WeeklyChoiceKind, optionID: String? = nil) {
        self.id = id
        self.at = at
        self.planID = planID
        self.kind = kind
        self.optionID = optionID
    }
}

public struct WeeklyFoundationObservation: Codable, Equatable, Sendable {
    public let id: String
    public let day: Date
    public let kind: FoundationKind
    public let done: Bool
    public let dismissed: Bool

    public init(id: String, day: Date, kind: FoundationKind, done: Bool, dismissed: Bool) {
        self.id = id
        self.day = day
        self.kind = kind
        self.done = done
        self.dismissed = dismissed
    }
}

public struct WeeklyFoodCorrectionObservation: Codable, Equatable, Sendable {
    public let id: String
    public let at: Date
    public let savedDishID: String
    public let dishName: String

    public init(id: String, at: Date, savedDishID: String, dishName: String) {
        self.id = id
        self.at = at
        self.savedDishID = savedDishID
        self.dishName = dishName
    }
}

public struct WeeklyInput: Codable, Equatable, Sendable {
    public let scope: WeeklyScope
    public let window: WeeklyWindow
    public let sleep: [WeeklySleepObservation]
    public let movement: [WeeklyMovementObservation]
    public let plans: [WeeklyPlanObservation]
    public let choices: [WeeklyChoiceObservation]
    public let foundations: [WeeklyFoundationObservation]
    public let foodCorrections: [WeeklyFoodCorrectionObservation]
    public let metrics: [WeeklyMetricEvent]

    public init(
        scope: WeeklyScope, window: WeeklyWindow, sleep: [WeeklySleepObservation] = [],
        movement: [WeeklyMovementObservation] = [], plans: [WeeklyPlanObservation] = [],
        choices: [WeeklyChoiceObservation] = [], foundations: [WeeklyFoundationObservation] = [],
        foodCorrections: [WeeklyFoodCorrectionObservation] = [], metrics: [WeeklyMetricEvent] = []
    ) {
        self.scope = scope
        self.window = window
        self.sleep = sleep
        self.movement = movement
        self.plans = plans
        self.choices = choices
        self.foundations = foundations
        self.foodCorrections = foodCorrections
        self.metrics = metrics
    }
}
