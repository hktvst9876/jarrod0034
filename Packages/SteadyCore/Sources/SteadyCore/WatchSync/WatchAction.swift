import Foundation

/// There is deliberately no Calendar, save-food, preference, or HealthKit-write action.
public enum WatchActionKind: Codable, Equatable, Sendable {
    case chooseAlternative(optionID: String)
    case logMovement(kind: WatchMovementKind, minutes: Int)
    case foundationDone(kind: FoundationKind, optionID: String)
    case savedMealHandoff(savedCorrectionID: String)
}

public struct WatchAction: Identifiable, Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let id: String
    public let snapshotID: String
    public let snapshotRevision: Int
    public let profileID: UUID
    public let useSampleData: Bool
    public let day: Date
    public let createdAt: Date
    public let kind: WatchActionKind

    public init(
        schemaVersion: Int = 1, id: String, snapshotID: String, snapshotRevision: Int,
        profileID: UUID, useSampleData: Bool, day: Date, createdAt: Date, kind: WatchActionKind
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.snapshotID = snapshotID
        self.snapshotRevision = snapshotRevision
        self.profileID = profileID
        self.useSampleData = useSampleData
        self.day = day
        self.createdAt = createdAt
        self.kind = kind
    }
}

public enum WatchRejectionReason: String, Error, Codable, Equatable, Sendable {
    case unsupportedVersion, malformedPayload, oversizedPayload, invalidIdentifier
    case staleDay, expiredSnapshot, futureTimestamp, invalidSnapshot, staleSnapshot
    case profileMismatch, sampleMismatch, contextChanged, safetyBlocked
    case unknownOption, invalidMovement, conflictingReplay, outboxFull
    case persistenceFailed, unavailable
}

public enum WatchReceiptStatus: Codable, Equatable, Sendable {
    case accepted
    case rejected(WatchRejectionReason)
}

/// Store this together with the mutation in one transaction. Replayed action IDs
/// return their stored receipt even after the original snapshot expires.
public struct WatchActionReceipt: Identifiable, Codable, Equatable, Sendable {
    public var id: String { action.id }
    public let schemaVersion: Int
    public let action: WatchAction
    public let status: WatchReceiptStatus
    public let processedAt: Date

    public init(
        schemaVersion: Int = 1, action: WatchAction, status: WatchReceiptStatus, processedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.action = action
        self.status = status
        self.processedAt = processedAt
    }
}

public struct WatchCurrentContext: Equatable, Sendable {
    public let profileID: UUID
    public let useSampleData: Bool
    public let day: Date
    public let snapshotID: String
    public let snapshotRevision: Int
    public let lowDataMode: Bool
    public let safetyBlocked: Bool
    public let alternativeOptionIDs: Set<String>
    public let foundationKind: FoundationKind?
    public let foundationOptionID: String?
    public let savedCorrectionIDs: Set<String>
    public let movementKinds: Set<WatchMovementKind>

    public init(
        profileID: UUID, useSampleData: Bool, day: Date, snapshotID: String,
        snapshotRevision: Int, lowDataMode: Bool, safetyBlocked: Bool,
        alternativeOptionIDs: Set<String> = [], foundationKind: FoundationKind? = nil,
        foundationOptionID: String? = nil, savedCorrectionIDs: Set<String> = [],
        movementKinds: Set<WatchMovementKind> = []
    ) {
        self.profileID = profileID
        self.useSampleData = useSampleData
        self.day = day
        self.snapshotID = snapshotID
        self.snapshotRevision = snapshotRevision
        self.lowDataMode = lowDataMode
        self.safetyBlocked = safetyBlocked
        self.alternativeOptionIDs = alternativeOptionIDs
        self.foundationKind = foundationKind
        self.foundationOptionID = foundationOptionID
        self.savedCorrectionIDs = savedCorrectionIDs
        self.movementKinds = movementKinds
    }

    public init(snapshot: WatchSnapshot) {
        self.init(
            profileID: snapshot.profileID, useSampleData: snapshot.useSampleData,
            day: snapshot.day, snapshotID: snapshot.id, snapshotRevision: snapshot.revision,
            lowDataMode: snapshot.lowDataMode, safetyBlocked: snapshot.safetyBlocked,
            alternativeOptionIDs: Set(snapshot.alternatives.map(\.id)),
            foundationKind: snapshot.foundation?.kind, foundationOptionID: snapshot.foundation?.optionID,
            savedCorrectionIDs: Set(snapshot.savedMeals.map(\.id)), movementKinds: Set(snapshot.movementKinds)
        )
    }
}

public enum WatchActionDecision: Equatable, Sendable {
    case apply
    case replay(WatchActionReceipt)
    case reject(WatchRejectionReason)
}
