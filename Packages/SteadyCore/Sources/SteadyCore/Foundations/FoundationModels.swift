import Foundation

public enum FoundationKind: String, Codable, CaseIterable, Hashable, Sendable {
    case mobility, daylight, hydration, movementBreak, reset, windDown
}

/// Only explicit controls are used; a free-text movement note is never interpreted.
public struct FoundationSettings: Codable, Equatable, Sendable {
    public let disabledKinds: Set<FoundationKind>
    public let movementMode: AlternativeMovementMode
    public let movementsToAvoid: Set<AlternativeMovement>

    public init(
        disabledKinds: Set<FoundationKind> = [],
        movementMode: AlternativeMovementMode = .standing,
        movementsToAvoid: Set<AlternativeMovement> = []
    ) {
        self.disabledKinds = disabledKinds
        self.movementMode = movementMode
        self.movementsToAvoid = movementsToAvoid
    }
}

public struct FoundationOption: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let kind: FoundationKind
    public let title: String
    public let minutes: Int?
    public let durationExplanation: String
    public let reason: String
    public let steps: [String]
    public let supportedMovementModes: Set<AlternativeMovementMode>
    public let requiredMovements: Set<AlternativeMovement>

    public init(
        id: String, kind: FoundationKind, title: String, minutes: Int?,
        durationExplanation: String, reason: String, steps: [String],
        supportedMovementModes: Set<AlternativeMovementMode> = Set(AlternativeMovementMode.allCases),
        requiredMovements: Set<AlternativeMovement> = []
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.minutes = minutes
        self.durationExplanation = durationExplanation
        self.reason = reason
        self.steps = steps
        self.supportedMovementModes = supportedMovementModes
        self.requiredMovements = requiredMovements
    }
}

public enum FoundationStatus: String, Codable, Equatable, Sendable {
    case available, replaced, snoozed, done, disabled
}

public struct FoundationItemState: Identifiable, Codable, Equatable, Sendable {
    public var id: FoundationKind { kind }
    public let kind: FoundationKind
    public let status: FoundationStatus
    public let optionID: String?
    public let snoozedUntil: Date?

    public init(
        kind: FoundationKind, status: FoundationStatus = .available,
        optionID: String? = nil, snoozedUntil: Date? = nil
    ) {
        self.kind = kind
        self.status = status
        self.optionID = optionID
        self.snoozedUntil = snoozedUntil
    }
}

public struct FoundationDayState: Codable, Equatable, Sendable {
    public let day: Date
    public let settings: FoundationSettings
    public let items: [FoundationItemState]
    public let appliedEventIDs: Set<String>

    public init(
        day: Date, settings: FoundationSettings = FoundationSettings(),
        items: [FoundationItemState] = [], appliedEventIDs: Set<String> = []
    ) {
        self.day = day
        self.settings = settings
        self.items = items
        self.appliedEventIDs = appliedEventIDs
    }
}

public enum FoundationAction: Codable, Equatable, Sendable {
    case done
    case replace(optionID: String)
    case snooze(until: Date)
    case disable
    case enable
    case resume
}

/// A captured day makes stale sheets and notification actions rejectable.
public struct FoundationEvent: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let day: Date
    public let kind: FoundationKind
    public let action: FoundationAction

    public init(id: String, day: Date, kind: FoundationKind, action: FoundationAction) {
        self.id = id
        self.day = day
        self.kind = kind
        self.action = action
    }
}

public enum FoundationError: String, Error, Codable, Equatable, Sendable {
    case emptyEventID, staleDay, invalidState, safetyBlocked
    case inactiveItem, unknownOption, unchangedOption, invalidSnooze, invalidTransition
}
