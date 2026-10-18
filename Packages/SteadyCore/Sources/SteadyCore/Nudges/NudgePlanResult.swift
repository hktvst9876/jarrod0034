import Foundation

public enum NudgeInterruptionLevel: String, Codable, Equatable, Sendable {
    case ordinary
}

public enum NudgeSilentReason: String, Codable, Equatable, Sendable {
    case canWait, notificationsUnavailable, reducedFrequency, budgetReached, alreadyReserved
}

public struct PlannedNudge: Identifiable, Codable, Equatable, Sendable {
    public let candidate: NudgeCandidate
    public let fireAt: Date
    public let silentReason: NudgeSilentReason?
    public let interruptionLevel: NudgeInterruptionLevel

    public var id: String { candidate.id }
    public var kind: FoundationKind { candidate.kind }
    public var title: String { candidate.title }
    public var body: String { candidate.body }

    public init(candidate: NudgeCandidate, fireAt: Date, silentReason: NudgeSilentReason? = nil) {
        self.candidate = candidate
        self.fireAt = fireAt
        self.silentReason = silentReason
        self.interruptionLevel = .ordinary
    }
}

public enum NudgeDropReason: String, Codable, Equatable, Sendable {
    case invalidContext, invalidCandidate, outsideDay, inThePast, disabled, completed
    case safetyBlocked, pausedAfterDismissals, duplicateID, duplicateKind
    case alreadyReserved, invalidSnooze, noUnblockedTime
}

public struct NudgeDrop: Codable, Equatable, Sendable {
    public let candidateID: String
    public let kind: FoundationKind
    public let reason: NudgeDropReason

    public init(candidateID: String, kind: FoundationKind, reason: NudgeDropReason) {
        self.candidateID = candidateID
        self.kind = kind
        self.reason = reason
    }
}

public struct NudgePlanResult: Codable, Equatable, Sendable {
    public let notifications: [PlannedNudge]
    public let silentCards: [PlannedNudge]
    public let drops: [NudgeDrop]

    public init(notifications: [PlannedNudge], silentCards: [PlannedNudge], drops: [NudgeDrop]) {
        self.notifications = notifications
        self.silentCards = silentCards
        self.drops = drops
    }
}
