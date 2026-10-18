import Foundation

/// WatchConnectivity carries only these bounded Data values inside fixed-key
/// property-list dictionaries. No unrestricted model dictionary crosses the link.
public enum WatchWireCodec {
    public static let snapshotMaximumBytes = 64_000
    public static let actionMaximumBytes = 8_192
    public static let receiptMaximumBytes = 20_480

    public static func encode(_ value: WatchSnapshot) throws -> Data {
        guard value.schemaVersion == 1 else { throw WatchRejectionReason.unsupportedVersion }
        return try encoded(value, maximum: snapshotMaximumBytes)
    }

    public static func encode(_ value: WatchAction) throws -> Data {
        guard value.schemaVersion == 1 else { throw WatchRejectionReason.unsupportedVersion }
        return try encoded(value, maximum: actionMaximumBytes)
    }

    public static func encode(_ value: WatchActionReceipt) throws -> Data {
        guard value.schemaVersion == 1, value.action.schemaVersion == 1 else {
            throw WatchRejectionReason.unsupportedVersion
        }
        return try encoded(value, maximum: receiptMaximumBytes)
    }

    public static func decodeSnapshot(_ data: Data) throws -> WatchSnapshot {
        let value: WatchSnapshot = try decoded(data, maximum: snapshotMaximumBytes)
        guard value.schemaVersion == 1 else { throw WatchRejectionReason.unsupportedVersion }
        return value
    }

    public static func decodeAction(_ data: Data) throws -> WatchAction {
        let value: WatchAction = try decoded(data, maximum: actionMaximumBytes)
        guard value.schemaVersion == 1 else { throw WatchRejectionReason.unsupportedVersion }
        return value
    }

    public static func decodeReceipt(_ data: Data) throws -> WatchActionReceipt {
        let value: WatchActionReceipt = try decoded(data, maximum: receiptMaximumBytes)
        guard value.schemaVersion == 1, value.action.schemaVersion == 1 else {
            throw WatchRejectionReason.unsupportedVersion
        }
        guard WatchPayloadRules.finite(value.processedAt), WatchPayloadRules.identifier(value.action.id) else {
            throw WatchRejectionReason.malformedPayload
        }
        return value
    }

    private static func encoded<Value: Encodable>(_ value: Value, maximum: Int) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data: Data
        do { data = try encoder.encode(value) } catch { throw WatchRejectionReason.malformedPayload }
        guard data.count <= maximum else { throw WatchRejectionReason.oversizedPayload }
        return data
    }

    private static func decoded<Value: Decodable>(_ data: Data, maximum: Int) throws -> Value {
        guard !data.isEmpty else { throw WatchRejectionReason.malformedPayload }
        guard data.count <= maximum else { throw WatchRejectionReason.oversizedPayload }
        do { return try JSONDecoder().decode(Value.self, from: data) }
        catch { throw WatchRejectionReason.malformedPayload }
    }
}
