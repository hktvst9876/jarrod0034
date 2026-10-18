import Foundation
import SteadyCore
import SwiftData

/// One global revision prevents an old profile or data mode from replacing a newer frame.
@Model
final class WatchIssuedSnapshotRecord {
    @Attribute(.unique) var key: String
    var revision: Int
    var bindingDigest: String
    var snapshotData: Data

    init(revision: Int, bindingDigest: String, snapshot: WatchSnapshot) throws {
        self.key = "latest"
        self.revision = revision
        self.bindingDigest = bindingDigest
        self.snapshotData = try JSONEncoder().encode(snapshot)
    }
}

/// Saved in the same transaction as its mutation. Transport retries only replay the receipt.
@Model
final class WatchActionReceiptRecord {
    @Attribute(.unique) var id: String
    var receiptData: Data
    var processedAt: Date

    init(receipt: WatchActionReceipt) throws {
        self.id = receipt.action.id
        self.receiptData = try JSONEncoder().encode(receipt)
        self.processedAt = receipt.processedAt
    }
}

/// Explicit manual observations only; this is not a HealthKit write or plan completion.
@Model
final class WatchMovementRecord {
    @Attribute(.unique) var id: String
    var profileID: UUID
    var sampleData: Bool
    var day: Date
    var kindRawValue: String
    var minutes: Int
    var observedAt: Date
    var receivedAt: Date

    init(action: WatchAction, kind: WatchMovementKind, minutes: Int, receivedAt: Date) {
        self.id = action.id
        self.profileID = action.profileID
        self.sampleData = action.useSampleData
        self.day = action.day
        self.kindRawValue = kind.rawValue
        self.minutes = minutes
        self.observedAt = action.createdAt
        self.receivedAt = receivedAt
    }
}

/// A durable navigation request, never a meal-completion or remembered-correction action.
@Model
final class WatchMealHandoffRecord {
    @Attribute(.unique) var id: String
    var profileID: UUID
    var sampleData: Bool
    var day: Date
    var correctionID: String
    var consumedAt: Date?

    init(action: WatchAction, correctionID: String) {
        self.id = action.id
        self.profileID = action.profileID
        self.sampleData = action.useSampleData
        self.day = action.day
        self.correctionID = correctionID
        self.consumedAt = nil
    }
}
