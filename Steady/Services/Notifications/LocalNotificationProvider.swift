import Foundation
import SteadyCore
@preconcurrency import UserNotifications

@MainActor
final class LocalNotificationProvider: NotificationProviding {
    private let center: UNUserNotificationCenter
    private let delegate = FoundationNotificationDelegate()

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        center.delegate = delegate
        let actions = [
            UNNotificationAction(identifier: "steady.foundation.done", title: "Done", options: [.foreground]),
            UNNotificationAction(identifier: "steady.foundation.snooze", title: "Snooze", options: [.foreground]),
            UNNotificationAction(identifier: "steady.foundation.disable", title: "Disable this type", options: [.foreground])
        ]
        let category = UNNotificationCategory(
            identifier: FoundationNotificationDelegate.categoryID, actions: actions,
            intentIdentifiers: [], options: [.customDismissAction]
        )
        center.setNotificationCategories([category])
    }

    func accessState() async -> NotificationAccessState {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: .authorized
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    func requestAccess() async throws -> NotificationAccessState {
        let revision = DataDeletionGate.shared.revision
        guard !DataDeletionGate.shared.isBlocked else { throw FoundationNotificationError.invalidRequest }
        _ = try await center.requestAuthorization(options: [.alert])
        guard current(revision) else { throw FoundationNotificationError.invalidRequest }
        return await accessState()
    }

    func pendingIdentifiers() async -> Set<String> {
        Set(await center.pendingNotificationRequests().map(\.identifier).filter { $0.hasPrefix(FoundationNotificationDelegate.prefix) })
    }

    func replace(_ reminders: [FoundationReminderRequest]) async throws {
        let revision = DataDeletionGate.shared.revision
        guard current(revision), reminders.allSatisfy({ ($0.privacyRevision ?? 0) == revision }) else {
            throw FoundationNotificationError.invalidRequest
        }
        let access = await accessState()
        guard current(revision) else { throw FoundationNotificationError.invalidRequest }
        guard access == .authorized else {
            await cancelAll()
            if reminders.isEmpty { return }
            throw FoundationNotificationError.permissionRequired
        }
        guard reminders.count <= 3, Set(reminders.map(\.id)).count == reminders.count else {
            throw FoundationNotificationError.invalidRequest
        }
        let desired = Set(reminders.map(\.id))
        let pending = await pendingIdentifiers()
        guard current(revision) else { throw FoundationNotificationError.invalidRequest }
        center.removePendingNotificationRequests(withIdentifiers: Array(pending.subtracting(desired)))
        let delivered = Set(await center.deliveredNotifications().map { $0.request.identifier })
        guard current(revision) else { throw FoundationNotificationError.invalidRequest }
        for value in reminders where !delivered.contains(value.id) {
            guard current(revision) else { throw FoundationNotificationError.invalidRequest }
            guard value.id.hasPrefix(FoundationNotificationDelegate.prefix),
                  value.fireAt > Date(), value.fireAt.timeIntervalSince1970.isFinite else { continue }
            let content = UNMutableNotificationContent()
            content.title = value.title
            content.body = value.body
            content.categoryIdentifier = FoundationNotificationDelegate.categoryID
            content.interruptionLevel = .active
            content.sound = nil
            content.userInfo = ["profile": value.profileID.uuidString, "kind": value.kind.rawValue,
                                "day": value.day.timeIntervalSince1970, "option": value.optionID ?? "",
                                "privacyRevision": revision]
            var components = SteadyCalendar.singapore().dateComponents([.year, .month, .day, .hour, .minute, .second], from: value.fireAt)
            components.calendar = SteadyCalendar.singapore()
            components.timeZone = SteadyCalendar.singapore().timeZone
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            do {
                try await center.add(UNNotificationRequest(identifier: value.id, content: content, trigger: trigger))
            } catch {
                if !current(revision) {
                    center.removePendingNotificationRequests(withIdentifiers: [value.id])
                    center.removeDeliveredNotifications(withIdentifiers: [value.id])
                }
                throw error
            }
            guard current(revision) else {
                // An OS add that completed after erase may remove only its own stale request.
                center.removePendingNotificationRequests(withIdentifiers: [value.id])
                center.removeDeliveredNotifications(withIdentifiers: [value.id])
                throw FoundationNotificationError.invalidRequest
            }
        }
    }

    func cancelAll() async {
        let ids = await pendingIdentifiers()
        center.removePendingNotificationRequests(withIdentifiers: Array(ids))
        let delivered = await center.deliveredNotifications().map(\.request.identifier)
            .filter { $0.hasPrefix(FoundationNotificationDelegate.prefix) }
        center.removeDeliveredNotifications(withIdentifiers: delivered)
    }

    private func current(_ revision: Int) -> Bool {
        !DataDeletionGate.shared.isBlocked && DataDeletionGate.shared.revision == revision
    }
}
