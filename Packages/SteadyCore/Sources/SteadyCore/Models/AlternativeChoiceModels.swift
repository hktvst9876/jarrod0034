import Foundation

public enum AlternativeChoiceAction: Codable, Equatable, Sendable {
    case choose(optionID: String)
    case later
    case restOnPurpose
    case complete
}

public struct AlternativeChoiceEvent: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let at: Date
    public let action: AlternativeChoiceAction

    public init(id: String, at: Date, action: AlternativeChoiceAction) {
        self.id = id
        self.at = at
        self.action = action
    }
}

public struct AlternativeChoiceState: Codable, Equatable, Sendable {
    public let plan: PlanItem
    public let selectedOption: AlternativeOption?
    public let appliedEventIDs: Set<String>

    public init(plan: PlanItem, selectedOption: AlternativeOption? = nil, appliedEventIDs: Set<String> = []) {
        self.plan = plan
        self.selectedOption = selectedOption
        self.appliedEventIDs = appliedEventIDs
    }
}

public enum AlternativeChoiceError: Error, Equatable, Sendable {
    case emptyEventID
    case safetyBlocked
    case unknownOrStaleOption
    case planFinished
    case cannotCompleteDeferredPlan
}
