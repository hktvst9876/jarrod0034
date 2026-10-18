import Foundation

/// A non-personal monotonic generation cutoff, sent only after explicit Delete all.
public struct CompanionEraseControl: Codable, Equatable, Sendable {
    public static let maximumBytes = 1_024
    public let schemaVersion: Int
    public let revision: Int
    public let createdAt: Date

    public init(schemaVersion: Int = 1, revision: Int, createdAt: Date) {
        self.schemaVersion = schemaVersion
        self.revision = revision
        self.createdAt = createdAt
    }

    public func encode() throws -> Data {
        try Self.encode(self)
    }

    public static func encode(_ control: CompanionEraseControl) throws -> Data {
        try control.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data: Data
        do { data = try encoder.encode(control) } catch { throw WatchRejectionReason.malformedPayload }
        guard data.count <= maximumBytes else { throw WatchRejectionReason.oversizedPayload }
        return data
    }

    public static func decode(_ data: Data) throws -> CompanionEraseControl {
        guard !data.isEmpty else { throw WatchRejectionReason.malformedPayload }
        guard data.count <= maximumBytes else { throw WatchRejectionReason.oversizedPayload }
        let control: CompanionEraseControl
        do {
            let decoded = try JSONSerialization.jsonObject(with: data)
            guard let fields = decoded as? [String: Any],
                  Set(fields.keys) == Set(["schemaVersion", "revision", "createdAt"]) else {
                throw WatchRejectionReason.malformedPayload
            }
            control = try JSONDecoder().decode(CompanionEraseControl.self, from: data)
        } catch { throw WatchRejectionReason.malformedPayload }
        try control.validate()
        return control
    }

    public func validate() throws {
        guard schemaVersion == 1 else { throw WatchRejectionReason.unsupportedVersion }
        guard revision > 0, createdAt.timeIntervalSinceReferenceDate.isFinite else {
            throw WatchRejectionReason.malformedPayload
        }
    }
}

extension WatchOutboxReducer {
    /// Not queue expiry: this is an explicit companion privacy erasure boundary.
    /// A late cutoff must not remove actions created from a newer generation.
    public static func erase(beforeOrAt revision: Int, in state: WatchOutboxState) throws -> WatchOutboxState {
        guard revision > 0 else { throw WatchRejectionReason.malformedPayload }
        try validate(state)
        return WatchOutboxState(actions: state.actions.filter { $0.snapshotRevision > revision },
                                receipts: state.receipts.filter { $0.action.snapshotRevision > revision })
    }
}
