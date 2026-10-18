import Foundation
import Observation
import SteadyCore

@MainActor
@Observable
final class WatchCompanionModel {
    private var state = WatchLocalState()
    private(set) var now: Date
    var message: String?
    var failure: String?
    private(set) var storageReady = false
    @ObservationIgnored private let clock: any SteadyCore.Clock
    @ObservationIgnored private let transport: any CompanionTransport
    @ObservationIgnored private let storage: WatchLocalStorage
    @ObservationIgnored private var lastAttempts: [String: Date] = [:]

    init(clock: any SteadyCore.Clock = SystemClock(), transport: any CompanionTransport = WCCompanionTransport(),
         storage: WatchLocalStorage = WatchLocalStorage()) {
        self.clock = clock
        self.now = clock.now
        self.transport = transport
        self.storage = storage
        do { state = try storage.read(); storageReady = true }
        catch { failure = "Could not open the companion queue. Existing actions have not been erased. Try reopening Steady." }
        transport.start()
    }

    var snapshot: WatchSnapshot? {
        guard !DataDeletionGate.shared.isBlocked, let value = state.snapshot,
              value.revision > DataDeletionGate.shared.revision,
              WatchSnapshotValidator.issue(in: value, clock: FixedClock(now: now)) == nil else { return nil }
        return value
    }
    var pending: [WatchAction] {
        guard !DataDeletionGate.shared.isBlocked else { return [] }
        return state.outbox.actions.filter { $0.snapshotRevision > DataDeletionGate.shared.revision }
    }
    var receipts: [WatchActionReceipt] {
        guard !DataDeletionGate.shared.isBlocked else { return [] }
        return Array(state.outbox.receipts.filter { $0.action.snapshotRevision > DataDeletionGate.shared.revision }.suffix(5).reversed())
    }
    var canAct: Bool { storageReady && snapshot != nil && snapshot?.useSampleData == false }

    func refresh(retry: Bool = true) {
        now = clock.now
        if !storageReady, DataDeletionGate.shared.currentErase != nil {
            do {
                state = try storage.read(); storageReady = true
                failure = nil
            } catch { failure = "The companion cache is unreadable. The privacy clear could not finish on this Watch; no new actions are enabled." }
        }
        guard storageReady else { return }
        do {
            try commit(storage.applyingPrivacyFence(to: state))
            try transport.resetLocalQueues()
            let inbox = try CompanionDiskInbox.shared.read()
            if let data = inbox.snapshot {
                do {
                    let incoming = try WatchWireCodec.decodeSnapshot(data)
                    if incoming.revision > DataDeletionGate.shared.revision {
                        switch WatchSnapshotValidator.accept(incoming, replacing: state.snapshot,
                            minimumRevision: state.revisionWatermark, clock: clock) {
                        case .accepted:
                            var next = state
                            next.snapshot = incoming; next.revisionWatermark = incoming.revision
                            try commit(next)
                        case .unchanged: break
                        case .rejected: break // Never roll back to an older frame.
                        }
                    }
                } catch let error as WatchRejectionReason {
                    // An unsupported frame cannot block application receipts. Hide
                    // cached content, retaining its watermark and every pending action.
                    if state.snapshot != nil { var next = state; next.snapshot = nil; try commit(next) }
                    failure = "A phone update is unsupported (\(error.rawValue)). Open Steady on iPhone."
                }
            }
            for data in inbox.receipts {
                do {
                    let receipt = try WatchWireCodec.decodeReceipt(data)
                    if receipt.action.snapshotRevision <= DataDeletionGate.shared.revision {
                        try CompanionDiskInbox.shared.removeReceipt(data)
                        continue
                    }
                    let nextOutbox = try WatchOutboxReducer.acknowledge(receipt, in: state.outbox)
                    var next = state; next.outbox = nextOutbox
                    try commit(next)
                    try CompanionDiskInbox.shared.removeReceipt(data)
                } catch let error as WatchRejectionReason {
                    // Unsupported/conflicting receipts cannot erase a pending action.
                    failure = "A companion receipt was not accepted (\(error.rawValue)). Open Steady on iPhone."
                    try CompanionDiskInbox.shared.removeReceipt(data)
                }
            }
            if retry { flush() }
        } catch {
            failure = "Could not update the companion queue. Pending actions remain saved; reopen both apps to retry."
        }
    }

    func queue(_ kind: WatchActionKind, from displayedSnapshot: WatchSnapshot) {
        now = clock.now
        guard canAct, let snapshot, snapshot == displayedSnapshot else {
            message = "This Watch view changed or expired. Review the current phone view before trying again."
            return
        }
        let duplicate: Bool
        if case .logMovement = kind {
            // Separate retrospective movement records are valid. Only suppress
            // rapid repeat taps, not another same-duration activity later.
            duplicate = state.outbox.actions.contains {
                $0.snapshotID == snapshot.id && $0.kind == kind && now.timeIntervalSince($0.createdAt) < 5
            }
        } else {
            duplicate = (state.outbox.actions + state.outbox.receipts.map(\.action)).contains {
                $0.snapshotID == snapshot.id && $0.kind == kind
            }
        }
        if duplicate { message = "This action is already queued or has a phone receipt."; return }
        let action = WatchAction(id: UUID().uuidString, snapshotID: snapshot.id, snapshotRevision: snapshot.revision,
            profileID: snapshot.profileID, useSampleData: snapshot.useSampleData, day: snapshot.day, createdAt: now, kind: kind)
        do {
            var next = state
            next.outbox = try WatchOutboxReducer.enqueue(action, to: next.outbox, snapshot: snapshot, clock: clock)
            try commit(next) // Must succeed before asking WatchConnectivity to transfer anything.
            message = "Queued for phone review, not yet applied. Open Steady on iPhone when convenient."
            failure = nil
            flush()
        } catch {
            failure = "Could not queue this action. Nothing new was sent; check the current phone view or queue space."
        }
    }

    func receiveInBackground() async {
        await transport.waitForPendingDelivery()
        refresh(retry: false)
    }

    private func flush() {
        guard transport.isAvailable, !DataDeletionGate.shared.isBlocked else { return }
        for action in pending {
            // Delivery callbacks are not phone receipts. Throttle retries, retaining
            // the same ID, so a sleeping phone cannot trigger a tight resend loop.
            if let attempt = lastAttempts[action.id], now.timeIntervalSince(attempt) < 120 { continue }
            do {
                try transport.sendAction(WatchWireCodec.encode(action))
                lastAttempts[action.id] = now
            } catch { message = "Pending actions stay on this Watch until companion transfer is available." }
        }
    }

    private func commit(_ value: WatchLocalState) throws {
        let filtered = try storage.applyingPrivacyFence(to: value)
        try storage.save(filtered)
        state = filtered
        let pendingIDs = Set(filtered.outbox.actions.map(\.id))
        lastAttempts = lastAttempts.filter { pendingIDs.contains($0.key) }
    }

}
