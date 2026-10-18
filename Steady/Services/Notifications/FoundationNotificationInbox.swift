import Foundation

/// The notification delegate never touches SwiftData or UI from its callback thread.
/// This small durable inbox is protected as one read/modify/write transaction.
final class FoundationNotificationInbox: @unchecked Sendable {
    static let shared = FoundationNotificationInbox()
    private let lock = NSLock()
    private let key = "steady.foundation.notification.responses"

    private init() {}

    func append(_ response: FoundationNotificationResponse) {
        lock.lock(); defer { lock.unlock() }
        guard !DataDeletionGate.shared.isBlocked,
              (response.privacyRevision ?? 0) == DataDeletionGate.shared.revision else { return }
        var values = read()
        guard !values.contains(where: { $0.id == response.id }) else { return }
        values.append(response)
        save(values)
    }

    func responses() -> [FoundationNotificationResponse] {
        lock.lock(); defer { lock.unlock() }
        guard !DataDeletionGate.shared.isBlocked else { return [] }
        return read().filter { ($0.privacyRevision ?? 0) == DataDeletionGate.shared.revision }
    }

    func remove(id: String) {
        lock.lock(); defer { lock.unlock() }
        save(read().filter { $0.id != id })
    }

    func clear() {
        lock.lock(); defer { lock.unlock() }
        UserDefaults.standard.removeObject(forKey: key)
    }

    private func read() -> [FoundationNotificationResponse] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let values = try? JSONDecoder().decode([FoundationNotificationResponse].self, from: data) else { return [] }
        return values
    }

    private func save(_ values: [FoundationNotificationResponse]) {
        guard let data = try? JSONEncoder().encode(values) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }
}
