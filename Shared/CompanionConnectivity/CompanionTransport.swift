import Foundation
import SteadyCore

@MainActor
protocol CompanionTransport {
    var isAvailable: Bool { get }
    var isReachable: Bool { get }
    func start()
    func publish(snapshot: Data) throws
    func sendAction(_ data: Data) throws
    func sendReceipt(_ data: Data) throws
    func requestErase(_ control: CompanionEraseControl) throws
    func resetLocalQueues() throws
    func waitForPendingDelivery() async
}

extension CompanionTransport {
    func waitForPendingDelivery() async {}
}

enum CompanionTransportError: LocalizedError {
    case unavailable, invalidPayload, queueFull, invalidStore
    var errorDescription: String? {
        switch self {
        case .unavailable: "The companion is not ready. Pending actions remain on this device."
        case .invalidPayload: "This companion update is not supported. Open Steady on the phone."
        case .queueFull: "The companion queue is full. Open Steady on both devices before adding another action."
        case .invalidStore: "Steady could not open its companion queue. Existing data has not been erased."
        }
    }
}

extension Notification.Name {
    static let companionInboxChanged = Notification.Name("steady.companion.inbox.changed")
}

/// No system session, delivery, or real inbox access in sample mode.
@MainActor
final class SampleCompanionTransport: CompanionTransport {
    var isAvailable: Bool { true }
    var isReachable: Bool { false }
    private(set) var latestSnapshot: Data?
    func start() {}
    func publish(snapshot: Data) throws { latestSnapshot = snapshot }
    func sendAction(_ data: Data) throws { throw CompanionTransportError.unavailable }
    func sendReceipt(_ data: Data) throws {}
    func requestErase(_ control: CompanionEraseControl) throws { throw CompanionTransportError.unavailable }
    func resetLocalQueues() throws { latestSnapshot = nil }
}
