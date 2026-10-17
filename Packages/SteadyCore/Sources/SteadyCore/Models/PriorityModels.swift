import Foundation

public enum PriorityKind: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case lookAfterYourself
    case protectBedtime
    case recover
    case keepItSmall
    case strength
    case getMoving
    case lighterDay
    case followPlan
    case steadyDay
}

public enum OutcomePart: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case sleepOpportunity
    case gentleMovement
    case strengthStimulus
    case aerobicMovement
    case stressRelief
    case dailyRoutine
    case nourishment
}

public struct Outcome: Codable, Equatable, Sendable {
    public let id: String
    public let summary: String
    public let parts: Set<OutcomePart>

    public init(id: String, summary: String, parts: Set<OutcomePart>) {
        self.id = id
        self.summary = summary
        self.parts = parts
    }
}

public enum PlanType: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case rest
    case windDown
    case walk
    case mobility
    case strength
    case cardio
    case downtime
    case planned
    case steadyDay
}

public enum PlanStatus: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case proposed
    case scheduled
    case completed
    case deferred
    case intentionallyRested
}

public enum PlanOrigin: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case priorityRule
    case user
    case calendar
    case condensed
}

public struct PlanItem: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let day: Date
    public let type: PlanType
    public let title: String
    public let outcome: Outcome
    public let minutes: Int
    public let slot: FreeSlot?
    public let status: PlanStatus
    public let origin: PlanOrigin

    public init(
        id: String,
        day: Date,
        type: PlanType,
        title: String,
        outcome: Outcome,
        minutes: Int,
        slot: FreeSlot?,
        status: PlanStatus = .proposed,
        origin: PlanOrigin
    ) {
        self.id = id
        self.day = day
        self.type = type
        self.title = title
        self.outcome = outcome
        self.minutes = max(0, minutes)
        self.slot = slot
        self.status = status
        self.origin = origin
    }

    public func condensed(maximumMinutes: Int = 25) -> PlanItem {
        let condensedMinutes = min(minutes, max(0, maximumMinutes))
        let condensedSlot = slot.map { slot in
            let proposedEnd = slot.start.addingTimeInterval(Double(condensedMinutes * 60))
            return FreeSlot(
                start: slot.start,
                end: min(slot.end, proposedEnd),
                travelAllowanceMinutes: slot.travelAllowanceMinutes,
                confidence: slot.confidence
            )
        }

        return PlanItem(
            id: id + "-condensed",
            day: day,
            type: type,
            title: "Short version: " + title,
            outcome: outcome,
            minutes: condensedMinutes,
            slot: condensedSlot,
            status: status,
            origin: .condensed
        )
    }
}

public struct ExplanationFactor: Codable, Equatable, Sendable {
    public let label: String
    public let displayValue: String
    public let why: String

    public init(label: String, displayValue: String, why: String) {
        self.label = label
        self.displayValue = displayValue
        self.why = why
    }
}

public struct Explanation: Codable, Equatable, Sendable {
    public let summary: String
    public let factors: [ExplanationFactor]

    public init(summary: String, factors: [ExplanationFactor] = []) {
        self.summary = summary
        self.factors = factors
    }
}

public struct DailyPriority: Codable, Equatable, Sendable {
    public let kind: PriorityKind
    public let ruleID: String
    public let title: String
    public let explanation: Explanation
    public let planA: PlanItem
    public let chosenByUser: Bool

    public init(
        kind: PriorityKind,
        ruleID: String,
        title: String,
        explanation: Explanation,
        planA: PlanItem,
        chosenByUser: Bool = false
    ) {
        self.kind = kind
        self.ruleID = ruleID
        self.title = title
        self.explanation = explanation
        self.planA = planA
        self.chosenByUser = chosenByUser
    }
}

