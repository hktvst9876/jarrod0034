import Foundation
import SteadyCore
@preconcurrency import UserNotifications

final class FoundationNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let categoryID = "steady.foundation.actions"
    static let prefix = "steady.foundation."

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // An open app already has a quiet Today card. Do not interrupt it again.
        completionHandler([])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        let request = response.notification.request
        let privacyRevision = request.content.userInfo["privacyRevision"] as? Int ?? 0
        guard !DataDeletionGate.shared.isBlocked, privacyRevision == DataDeletionGate.shared.revision,
              request.identifier.hasPrefix(Self.prefix),
              let profile = request.content.userInfo["profile"] as? String,
              let profileID = UUID(uuidString: profile),
              let rawKind = request.content.userInfo["kind"] as? String,
              let kind = FoundationKind(rawValue: rawKind),
              let dayValue = request.content.userInfo["day"] as? Double else { return }
        let action: FoundationNotificationAction
        switch response.actionIdentifier {
        case "steady.foundation.done": action = .done
        case "steady.foundation.snooze": action = .snooze
        case "steady.foundation.disable": action = .disable
        case UNNotificationDismissActionIdentifier: action = .dismiss
        case UNNotificationDefaultActionIdentifier: action = .open
        default: return
        }
        let value = FoundationNotificationResponse(
            id: request.identifier + ":" + action.rawValue,
            requestID: request.identifier, profileID: profileID,
            day: Date(timeIntervalSince1970: dayValue), kind: kind,
            optionID: request.content.userInfo["option"] as? String,
            action: action, at: Date(), privacyRevision: privacyRevision
        )
        FoundationNotificationInbox.shared.append(value)
        // Foreground actions open the app; its main-actor store validates and applies them.
        Task { @MainActor in
            guard !DataDeletionGate.shared.isBlocked, privacyRevision == DataDeletionGate.shared.revision else { return }
            NotificationCenter.default.post(name: .foundationNotificationResponse, object: nil)
        }
    }
}

extension Notification.Name {
    static let foundationNotificationResponse = Notification.Name("steady.foundation.notification.response")
}
