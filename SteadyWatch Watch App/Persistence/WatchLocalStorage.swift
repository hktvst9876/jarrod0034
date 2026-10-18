import Foundation
import SteadyCore

struct WatchLocalState: Codable {
    var snapshot: WatchSnapshot?
    var revisionWatermark = 0
    var outbox = WatchOutboxState()
}

/// One atomic file keeps snapshot acceptance, watermark, pending actions and
/// application receipts consistent across termination. An unreadable generation
/// fails closed; a historical erase marker cannot justify erasing newer data.
struct WatchLocalStorage {
    func read() throws -> WatchLocalState {
        let url = try location()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return try applyingPrivacyFence(to: WatchLocalState())
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        guard let bytes = attributes[.size] as? NSNumber, bytes.intValue <= 10_000_000 else {
            throw CompanionTransportError.invalidStore
        }
        let value = try JSONDecoder().decode(WatchLocalState.self, from: Data(contentsOf: url))
        try WatchOutboxReducer.validate(value.outbox)
        guard value.revisionWatermark >= 0, value.outbox.actions.count <= 50,
              value.outbox.receipts.count <= 100,
              value.snapshot.map({ $0.revision == value.revisionWatermark }) ?? true else {
            throw CompanionTransportError.invalidStore
        }
        let filtered = try applyingPrivacyFence(to: value)
        if filtered.revisionWatermark != value.revisionWatermark ||
            filtered.snapshot != value.snapshot || filtered.outbox != value.outbox {
            try save(filtered)
        }
        return filtered
    }

    func save(_ value: WatchLocalState) throws {
        let value = try applyingPrivacyFence(to: value)
        try WatchOutboxReducer.validate(value.outbox)
        guard value.snapshot.map({ $0.revision == value.revisionWatermark }) ?? true else {
            throw CompanionTransportError.invalidStore
        }
        let url = try location()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(value).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }

    func applyingPrivacyFence(to value: WatchLocalState) throws -> WatchLocalState {
        guard !DataDeletionGate.shared.isBlocked else { throw CompanionTransportError.invalidStore }
        guard let control = DataDeletionGate.shared.currentErase else { return value }
        var next = value
        next.outbox = try WatchOutboxReducer.erase(beforeOrAt: control.revision, in: value.outbox)
        if let snapshot = next.snapshot, snapshot.revision <= control.revision { next.snapshot = nil }
        next.revisionWatermark = max(next.revisionWatermark, control.revision)
        return next
    }

    private func location() throws -> URL {
        guard let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw CompanionTransportError.invalidStore
        }
        return root.appendingPathComponent("SteadyCompanion", isDirectory: true).appendingPathComponent("watch-state-v1.json")
    }
}
