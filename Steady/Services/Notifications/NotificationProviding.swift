import Foundation
import SteadyCore

enum NotificationAccessState: Sendable, Equatable {
    case notDetermined, denied, authorized
}

struct FoundationReminderRequest: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let profileID: UUID
    let day: Date
    let kind: FoundationKind
    let optionID: String?
    let fireAt: Date
    let title: String
    let body: String
    var privacyRevision: Int? = nil
}

enum FoundationNotificationAction: String, Codable, Equatable, Sendable {
    case open, done, snooze, disable, dismiss
}

struct FoundationNotificationResponse: Identifiable, Codable, Equatable, Sendable {
    let id: String
    let requestID: String
    let profileID: UUID
    let day: Date
    let kind: FoundationKind
    let optionID: String?
    let action: FoundationNotificationAction
    let at: Date
    var privacyRevision: Int? = nil
}

@MainActor
protocol NotificationProviding: AnyObject {
    func accessState() async -> NotificationAccessState
    func requestAccess() async throws -> NotificationAccessState
    func pendingIdentifiers() async -> Set<String>
    func replace(_ reminders: [FoundationReminderRequest]) async throws
    func cancelAll() async
}

enum FoundationNotificationError: LocalizedError {
    case permissionRequired, invalidRequest

    var errorDescription: String? {
        switch self {
        case .permissionRequired: "Notifications are off. Your foundation actions remain available in the app."
        case .invalidRequest: "This reminder is no longer current. Open Foundations to refresh."
        }
    }
}
