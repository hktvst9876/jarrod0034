import Foundation
import SteadyCore
@preconcurrency import WatchConnectivity

@MainActor
final class WCCompanionTransport: NSObject, CompanionTransport, WCSessionDelegate {
    private var session: WCSession?
    private var lastSubmittedEraseRevision: Int?
    private static let snapshotKey = "steady.snapshot.v1"
    private static let actionKey = "steady.action.v1"
    private static let receiptKey = "steady.receipt.v1"
    private static let eraseKey = "steady.erase.v1"

    var isAvailable: Bool {
        guard let session, session.activationState == .activated else { return false }
        #if os(iOS)
        return session.isPaired && session.isWatchAppInstalled
        #else
        return session.isCompanionAppInstalled
        #endif
    }
    var isReachable: Bool { isAvailable && session?.isReachable == true }

    func start() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        self.session = session
        session.delegate = self
        if session.activationState != .activated { session.activate() }
        else { retryEraseAfterSessionChange() }
    }

    func publish(snapshot: Data) throws {
        try validate(snapshot)
        let value = try WatchWireCodec.decodeSnapshot(snapshot)
        guard !DataDeletionGate.shared.isBlocked, value.revision > DataDeletionGate.shared.revision else {
            throw CompanionTransportError.unavailable
        }
        guard isAvailable, let session else { throw CompanionTransportError.unavailable }
        try session.updateApplicationContext([Self.snapshotKey: snapshot])
    }

    func sendAction(_ data: Data) throws {
        let value = try WatchWireCodec.decodeAction(data)
        guard !DataDeletionGate.shared.isBlocked, value.snapshotRevision > DataDeletionGate.shared.revision else {
            throw CompanionTransportError.unavailable
        }
        try transfer(data, key: Self.actionKey)
    }
    func sendReceipt(_ data: Data) throws {
        let value = try WatchWireCodec.decodeReceipt(data)
        guard !DataDeletionGate.shared.isBlocked, value.action.snapshotRevision > DataDeletionGate.shared.revision else {
            throw CompanionTransportError.unavailable
        }
        try transfer(data, key: Self.receiptKey)
    }

    func requestErase(_ control: CompanionEraseControl) throws {
        let data = try control.encode()
        try resetLocalQueues()
        guard lastSubmittedEraseRevision != control.revision else { return }
        guard isAvailable, let session else { throw CompanionTransportError.unavailable }
        var context: [String: Any] = [Self.eraseKey: data]
        if let latest = session.applicationContext[Self.snapshotKey] as? Data,
           let snapshot = try? WatchWireCodec.decodeSnapshot(latest), snapshot.revision > control.revision {
            context[Self.snapshotKey] = latest
        }
        try session.updateApplicationContext(context)
        try transfer(data, key: Self.eraseKey)
        lastSubmittedEraseRevision = control.revision
    }

    func resetLocalQueues() throws {
        guard let control = DataDeletionGate.shared.currentErase else { return }
        try CompanionDiskInbox.shared.erase(beforeOrAt: control.revision)
        guard let session else { return }
        for transfer in session.outstandingUserInfoTransfers {
            if let data = transfer.userInfo[Self.actionKey] as? Data,
               (try? WatchWireCodec.decodeAction(data).snapshotRevision).map({ $0 <= control.revision }) != false {
                transfer.cancel()
            }
            if let data = transfer.userInfo[Self.receiptKey] as? Data,
               (try? WatchWireCodec.decodeReceipt(data).action.snapshotRevision).map({ $0 <= control.revision }) != false {
                transfer.cancel()
            }
        }
    }

    func waitForPendingDelivery() async {
        start()
        guard WCSession.isSupported() else { return }
        // SwiftUI owns the background task. Return only after receipt is drained,
        // or when the system cancels its allotted background time.
        while !Task.isCancelled {
            if let session, session.activationState == .activated, !session.hasContentPending { return }
            do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
        }
    }

    private func transfer(_ data: Data, key: String) throws {
        try validate(data)
        guard isAvailable, let session else { throw CompanionTransportError.unavailable }
        // Reachability is NOT required for queued transferUserInfo delivery.
        guard !session.outstandingUserInfoTransfers.contains(where: { ($0.userInfo[key] as? Data) == data }) else { return }
        session.transferUserInfo([key: data])
    }

    private func validate(_ data: Data) throws {
        guard !data.isEmpty, data.count <= CompanionDiskInbox.maximumPayloadBytes else {
            throw CompanionTransportError.invalidPayload
        }
    }

    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState,
                            error: (any Error)?) {
        retryEraseAfterSessionChange(resetSubmission: true)
        notify()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        retryEraseAfterSessionChange(resetSubmission: true); notify()
    }

    #if os(iOS)
    nonisolated func sessionDidBecomeInactive(_ session: WCSession) { notify() }
    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        Task { @MainActor [weak self] in self?.start() }
    }
    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        retryEraseAfterSessionChange(resetSubmission: true); notify()
    }
    #endif

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        #if os(watchOS)
        if let eraseData = applicationContext["steady.erase.v1"] as? Data {
            receiveErase(eraseData)
        }
        #endif
        guard let data = applicationContext["steady.snapshot.v1"] as? Data else { return }
        do { try CompanionDiskInbox.shared.receiveSnapshot(data); notify() }
        catch { notify() } // No receipt: the sender/outbox must not infer success.
    }

    nonisolated func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        do {
            #if os(iOS)
            if let data = userInfo["steady.action.v1"] as? Data { try CompanionDiskInbox.shared.appendAction(data) }
            #else
            if let data = userInfo["steady.erase.v1"] as? Data { receiveErase(data) }
            if let data = userInfo["steady.receipt.v1"] as? Data { try CompanionDiskInbox.shared.appendReceipt(data) }
            #endif
            notify()
        } catch { notify() }
    }

    nonisolated func session(_ session: WCSession, didFinish userInfoTransfer: WCSessionUserInfoTransfer, error: (any Error)?) {
        // OS delivery is not application acknowledgement; do not remove any action.
        notify()
    }

    private nonisolated func notify() {
        Task { @MainActor in NotificationCenter.default.post(name: .companionInboxChanged, object: nil) }
    }

    private nonisolated func receiveErase(_ data: Data) {
        do {
            let control = try CompanionEraseControl.decode(data)
            try DataDeletionGate.shared.receiveErase(control)
            try CompanionDiskInbox.shared.erase(beforeOrAt: DataDeletionGate.shared.revision)
            notify()
        } catch { notify() }
    }

    private nonisolated func retryEraseAfterSessionChange(resetSubmission: Bool = false) {
        #if os(iOS)
        Task { @MainActor [weak self] in
            guard let self else { return }
            if resetSubmission { self.lastSubmittedEraseRevision = nil }
            if let control = DataDeletionGate.shared.currentErase { try? self.requestErase(control) }
        }
        #endif
    }
}
