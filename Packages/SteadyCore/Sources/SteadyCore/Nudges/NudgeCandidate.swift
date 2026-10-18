import Foundation

public enum NudgeOrigin: Codable, Equatable, Sendable {
    case automatic
    case snooze(replacingID: String)
}

/// A proposed action, not permission to schedule a notification.
public struct NudgeCandidate: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let kind: FoundationKind
    public let title: String
    public let body: String
    public let fireAt: Date
    public let expiresAt: Date
    public let durationMinutes: Int
    public let canWait: Bool
    public let origin: NudgeOrigin

    public init(
        id: String, kind: FoundationKind, title: String, body: String,
        fireAt: Date, expiresAt: Date, durationMinutes: Int,
        canWait: Bool, origin: NudgeOrigin = .automatic
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.body = body
        self.fireAt = fireAt
        self.expiresAt = expiresAt
        self.durationMinutes = durationMinutes
        self.canWait = canWait
        self.origin = origin
    }
}

/// Keep every reserved ID, including cancelled/failed deliveries, until the day ends.
/// History for earlier local days supports reduced-frequency suppression.
public struct NudgeReservation: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let kind: FoundationKind
    public let day: Date
    public let fireAt: Date?

    public init(id: String, kind: FoundationKind, day: Date, fireAt: Date? = nil) {
        self.id = id
        self.kind = kind
        self.day = day
        self.fireAt = fireAt
    }
}

/// Recurs in the injected calendar. Equal endpoints mean quiet all day.
public struct NudgeQuietPeriod: Codable, Equatable, Sendable {
    public let startMinute: Int
    public let endMinute: Int

    public init(startMinute: Int, endMinute: Int) {
        self.startMinute = startMinute
        self.endMinute = endMinute
    }
}
