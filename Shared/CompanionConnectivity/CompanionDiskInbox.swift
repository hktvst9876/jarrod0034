import Foundation
import SteadyCore

struct CompanionInboxState: Codable, Sendable {
    var snapshot: Data?
    var actions: [Data] = []
    var receipts: [Data] = []
}

/// Every operation holds the lock, including atomic disk replacement. Delegate
/// callbacks persist before returning, rather than relying on a later UI task.
final class CompanionDiskInbox: @unchecked Sendable {
    static let shared = CompanionDiskInbox()
    static let maximumPayloadBytes = 64_000
    private let lock = NSLock()

    func read() throws -> CompanionInboxState {
        lock.lock(); defer { lock.unlock() }
        return try load()
    }

    func receiveSnapshot(_ data: Data) throws {
        try validate(data)
        let snapshot = try WatchWireCodec.decodeSnapshot(data)
        guard !DataDeletionGate.shared.isBlocked, snapshot.revision > DataDeletionGate.shared.revision else { return }
        try change { value in
            guard !DataDeletionGate.shared.isBlocked, snapshot.revision > DataDeletionGate.shared.revision else { return }
            value.snapshot = data
        }
    }

    func appendAction(_ data: Data) throws { try append(data, action: true) }
    func appendReceipt(_ data: Data) throws { try append(data, action: false) }
    func removeAction(_ data: Data) throws { try change { $0.actions.removeAll { $0 == data } } }
    func removeReceipt(_ data: Data) throws { try change { $0.receipts.removeAll { $0 == data } } }

    func eraseAllPersonalData() throws {
        lock.lock(); defer { lock.unlock() }
        guard DataDeletionGate.shared.isBlocked, DataDeletionGate.shared.currentErase != nil else {
            throw CompanionTransportError.invalidStore
        }
        // The current confirmed phone reset authorises this exact raw inbox wipe,
        // including corrupt bytes. Do not decode or reuse an abandoned payload.
        let url = try location()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(CompanionInboxState()).write(to: url,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    /// Called only for an explicitly persisted privacy cutoff. Unknown payloads
    /// cannot prove that they belong to a later generation, so are also removed.
    func erase(beforeOrAt revision: Int) throws {
        guard revision > 0 else { throw CompanionTransportError.invalidPayload }
        try change { value in
            if let data = value.snapshot,
               (try? WatchWireCodec.decodeSnapshot(data).revision).map({ $0 > revision }) != true {
                value.snapshot = nil
            }
            value.actions = value.actions.filter {
                (try? WatchWireCodec.decodeAction($0).snapshotRevision).map { $0 > revision } == true
            }
            value.receipts = value.receipts.filter {
                (try? WatchWireCodec.decodeReceipt($0).action.snapshotRevision).map { $0 > revision } == true
            }
        }
    }

    private func append(_ data: Data, action: Bool) throws {
        try validate(data)
        let revision: Int
        if action { revision = try WatchWireCodec.decodeAction(data).snapshotRevision }
        else { revision = try WatchWireCodec.decodeReceipt(data).action.snapshotRevision }
        guard !DataDeletionGate.shared.isBlocked, revision > DataDeletionGate.shared.revision else { return }
        try change { value in
            guard !DataDeletionGate.shared.isBlocked, revision > DataDeletionGate.shared.revision else { return }
            if (action ? value.actions : value.receipts).contains(data) { return }
            guard value.actions.count + value.receipts.count < 100 else { throw CompanionTransportError.queueFull }
            if action { value.actions.append(data) } else { value.receipts.append(data) }
        }
    }

    private func validate(_ data: Data) throws {
        guard !data.isEmpty, data.count <= Self.maximumPayloadBytes else { throw CompanionTransportError.invalidPayload }
    }

    private func location() throws -> URL {
        guard let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CompanionTransportError.invalidStore
        }
        return base.appendingPathComponent("SteadyCompanion", isDirectory: true).appendingPathComponent("inbox-v1.json")
    }

    private func load() throws -> CompanionInboxState {
        let url = try location()
        guard FileManager.default.fileExists(atPath: url.path) else { return CompanionInboxState() }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let size = attributes[.size] as? NSNumber, size.intValue <= 10_000_000 else {
            throw CompanionTransportError.invalidStore
        }
        let value = try JSONDecoder().decode(CompanionInboxState.self, from: Data(contentsOf: url))
        guard value.actions.count + value.receipts.count <= 100,
              value.actions.allSatisfy({ !$0.isEmpty && $0.count <= Self.maximumPayloadBytes }),
              value.receipts.allSatisfy({ !$0.isEmpty && $0.count <= Self.maximumPayloadBytes }),
              value.snapshot.map({ !$0.isEmpty && $0.count <= Self.maximumPayloadBytes }) ?? true else {
            throw CompanionTransportError.invalidStore
        }
        return value
    }

    private func change(_ update: (inout CompanionInboxState) throws -> Void) throws {
        lock.lock(); defer { lock.unlock() }
        var value = try load()
        try update(&value)
        let url = try location()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
