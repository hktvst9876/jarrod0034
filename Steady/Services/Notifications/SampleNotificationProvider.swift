import Foundation

@MainActor
final class SampleNotificationProvider: NotificationProviding {
    private var allowed = false
    private var reminders: [FoundationReminderRequest] = []

    func accessState() async -> NotificationAccessState { allowed ? .authorized : .notDetermined }
    func requestAccess() async -> NotificationAccessState {
        guard !DataDeletionGate.shared.isBlocked else { return .notDetermined }
        allowed = true; return .authorized
    }
    func pendingIdentifiers() async -> Set<String> { Set(reminders.map(\.id)) }
    func replace(_ values: [FoundationReminderRequest]) throws {
        guard !DataDeletionGate.shared.isBlocked,
              values.allSatisfy({ ($0.privacyRevision ?? 0) == DataDeletionGate.shared.revision }) else {
            throw FoundationNotificationError.invalidRequest
        }
        guard allowed || values.isEmpty else { throw FoundationNotificationError.permissionRequired }
        reminders = values
    }
    func cancelAll() { reminders = [] }
}
