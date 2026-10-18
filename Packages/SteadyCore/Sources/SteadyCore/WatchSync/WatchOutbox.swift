import Foundation

public struct WatchOutboxState: Codable, Equatable, Sendable {
    public let actions: [WatchAction]
    public let receipts: [WatchActionReceipt]

    public init(actions: [WatchAction] = [], receipts: [WatchActionReceipt] = []) {
        self.actions = actions
        self.receipts = receipts
    }
}

public enum WatchOutboxReducer {
    public static let maximumPendingActions = 50
    public static let maximumDisplayedReceipts = 100

    /// Persist the returned state successfully before transferring. Every retry
    /// reuses this exact action, including its ID and timestamp.
    public static func enqueue(
        _ action: WatchAction, to state: WatchOutboxState, snapshot: WatchSnapshot,
        clock: any Clock, calendar: Calendar = SteadyCalendar.singapore()
    ) throws -> WatchOutboxState {
        try validate(state)
        if let pending = state.actions.first(where: { $0.id == action.id }) {
            guard pending == action else { throw WatchRejectionReason.conflictingReplay }
            return state
        }
        switch WatchActionValidator.evaluate(
            action, snapshot: snapshot, current: WatchCurrentContext(snapshot: snapshot),
            receipts: state.receipts, clock: clock, calendar: calendar
        ) {
        case .apply: break
        case .replay: return state
        case .reject(let reason): throw reason
        }
        guard state.actions.count < maximumPendingActions else { throw WatchRejectionReason.outboxFull }
        return WatchOutboxState(actions: state.actions + [action], receipts: state.receipts)
    }

    /// OS transfer completion is not an acknowledgement. Only a matching durable
    /// phone receipt removes an action; old-scope receipts may finish old actions.
    public static func acknowledge(
        _ receipt: WatchActionReceipt, in state: WatchOutboxState
    ) throws -> WatchOutboxState {
        try validate(state)
        guard (try? WatchWireCodec.encode(receipt)) != nil,
              WatchPayloadRules.finite(receipt.processedAt) else { throw WatchRejectionReason.malformedPayload }
        if case .accepted = receipt.status, receipt.processedAt < receipt.action.createdAt {
            throw WatchRejectionReason.malformedPayload
        }
        if let prior = state.receipts.first(where: { $0.id == receipt.id }) {
            guard prior == receipt else { throw WatchRejectionReason.conflictingReplay }
            return state
        }
        guard let pending = state.actions.first(where: { $0.id == receipt.id }) else {
            throw WatchRejectionReason.unknownOption
        }
        guard pending == receipt.action else { throw WatchRejectionReason.conflictingReplay }
        let history = Array((state.receipts + [receipt]).suffix(maximumDisplayedReceipts))
        return WatchOutboxState(actions: state.actions.filter { $0.id != receipt.id }, receipts: history)
    }

    public static func validate(_ state: WatchOutboxState) throws {
        guard state.actions.count <= maximumPendingActions,
              state.receipts.count <= maximumDisplayedReceipts,
              Set(state.actions.map(\.id)).count == state.actions.count,
              Set(state.receipts.map(\.id)).count == state.receipts.count,
              Set(state.actions.map(\.id)).isDisjoint(with: Set(state.receipts.map(\.id))),
              state.actions.allSatisfy({ (try? WatchWireCodec.encode($0)) != nil }),
              state.receipts.allSatisfy({ (try? WatchWireCodec.encode($0)) != nil }) else {
            throw WatchRejectionReason.malformedPayload
        }
    }
}
