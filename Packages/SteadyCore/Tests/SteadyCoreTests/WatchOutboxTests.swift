import Foundation
import Testing
@testable import SteadyCore

struct WatchOutboxTests {
    @Test func disconnectedQueueSurvivesCodableRoundTripWithStableAction() throws {
        let action = watchAction()
        let state = try WatchOutboxReducer.enqueue(action, to: WatchOutboxState(), snapshot: watchSnapshot(), clock: watchClock)
        let restored = try JSONDecoder().decode(WatchOutboxState.self, from: JSONEncoder().encode(state))
        #expect(restored == state)
        #expect(restored.actions == [action])
        #expect(restored.receipts.isEmpty)
    }

    @Test func retryReusesOriginalPayloadAndCannotRetimestampID() throws {
        let action = watchAction()
        let state = try WatchOutboxReducer.enqueue(action, to: WatchOutboxState(), snapshot: watchSnapshot(), clock: watchClock)
        let retry = try WatchOutboxReducer.enqueue(action, to: state, snapshot: watchSnapshot(), clock: FixedClock(now: watchNow.addingTimeInterval(30_000)))
        #expect(retry == state)
        #expect(throws: WatchRejectionReason.conflictingReplay) {
            try WatchOutboxReducer.enqueue(watchAction(createdAt: watchNow.addingTimeInterval(1)), to: state, snapshot: watchSnapshot(), clock: watchClock)
        }
    }

    @Test func onlyMatchingDurableReceiptRemovesPendingAction() throws {
        let action = watchAction()
        let state = WatchOutboxState(actions: [action])
        let receipt = WatchActionReceipt(action: action, status: .accepted, processedAt: watchNow)
        let acknowledged = try WatchOutboxReducer.acknowledge(receipt, in: state)
        #expect(acknowledged.actions.isEmpty)
        #expect(acknowledged.receipts == [receipt])
        #expect(try WatchOutboxReducer.acknowledge(receipt, in: acknowledged) == acknowledged)
        #expect(try WatchOutboxReducer.enqueue(action, to: acknowledged, snapshot: watchSnapshot(), clock: watchClock) == acknowledged)
    }

    @Test func forgedOrConflictingReceiptCannotDropPendingAction() {
        let state = WatchOutboxState(actions: [watchAction()])
        let forged = WatchActionReceipt(action: watchAction(kind: .logMovement(kind: .walk, minutes: 10)), status: .accepted, processedAt: watchNow)
        #expect(throws: WatchRejectionReason.conflictingReplay) { try WatchOutboxReducer.acknowledge(forged, in: state) }
        let unrelated = WatchActionReceipt(action: watchAction(id: "unrelated"), status: .accepted, processedAt: watchNow)
        #expect(throws: WatchRejectionReason.unknownOption) { try WatchOutboxReducer.acknowledge(unrelated, in: state) }
        #expect(state.actions.count == 1)
    }

    @Test func clockSkewRejectionCanClearMatchingFutureDatedAction() throws {
        let future = watchAction(createdAt: watchNow.addingTimeInterval(300))
        let state = WatchOutboxState(actions: [future])
        let rejected = WatchActionReceipt(action: future, status: .rejected(.futureTimestamp), processedAt: watchNow)
        #expect(try WatchOutboxReducer.acknowledge(rejected, in: state).actions.isEmpty)
        let impossibleAccepted = WatchActionReceipt(action: future, status: .accepted, processedAt: watchNow)
        #expect(throws: WatchRejectionReason.malformedPayload) {
            try WatchOutboxReducer.acknowledge(impossibleAccepted, in: state)
        }
    }

    @Test func queueIsBoundedAndNeverSilentlyEvictsPendingActions() {
        let actions = (0..<WatchOutboxReducer.maximumPendingActions).map { watchAction(id: "pending-\($0)") }
        let state = WatchOutboxState(actions: actions)
        #expect(throws: WatchRejectionReason.outboxFull) {
            try WatchOutboxReducer.enqueue(watchAction(id: "overflow"), to: state, snapshot: watchSnapshot(), clock: watchClock)
        }
        #expect(state.actions == actions)
    }

    @Test func malformedDurableQueueFailsClosed() {
        #expect(throws: WatchRejectionReason.malformedPayload) {
            try WatchOutboxReducer.validate(WatchOutboxState(actions: [watchAction(), watchAction()]))
        }
        let receipt = WatchActionReceipt(action: watchAction(), status: .accepted, processedAt: watchNow)
        #expect(throws: WatchRejectionReason.malformedPayload) {
            try WatchOutboxReducer.validate(WatchOutboxState(actions: [watchAction()], receipts: [receipt]))
        }
    }

    @Test func receiptHistoryIsBoundedButPendingActionsAreNotPruned() throws {
        let receipts = (0..<100).map {
            WatchActionReceipt(action: watchAction(id: "old-\($0)"), status: .accepted, processedAt: watchNow)
        }
        let pending = watchAction(id: "next")
        let other = watchAction(id: "still-pending")
        let state = WatchOutboxState(actions: [pending, other], receipts: receipts)
        let result = try WatchOutboxReducer.acknowledge(
            WatchActionReceipt(action: pending, status: .accepted, processedAt: watchNow), in: state
        )
        #expect(result.receipts.count == 100)
        #expect(result.receipts.last?.id == pending.id)
        #expect(result.actions == [other])
    }
}
