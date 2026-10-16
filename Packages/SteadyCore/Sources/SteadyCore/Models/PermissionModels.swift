import Foundation

public enum PermissionKind: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case health
    case calendar
    case notifications
    case location
}

public enum AuthorizationState: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case notDetermined
    case denied
    case authorized
    case unavailable
}

public struct PermissionStatus: Codable, Equatable, Sendable {
    public let kind: PermissionKind
    public let state: AuthorizationState
    public let checkedAt: Date

    public init(kind: PermissionKind, state: AuthorizationState, checkedAt: Date) {
        self.kind = kind
        self.state = state
        self.checkedAt = checkedAt
    }
}

public enum ConsentScope: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case onDeviceWellnessData
    case approximateLocation
    case advisorDataEgress
}

public struct ConsentRecord: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let scope: ConsentScope
    public let grantedAt: Date
    public let revokedAt: Date?
    public let noticeVersion: Int

    public init(
        id: UUID,
        scope: ConsentScope,
        grantedAt: Date,
        revokedAt: Date? = nil,
        noticeVersion: Int
    ) {
        self.id = id
        self.scope = scope
        self.grantedAt = grantedAt
        self.revokedAt = revokedAt
        self.noticeVersion = max(1, noticeVersion)
    }

    public var isActive: Bool {
        revokedAt == nil
    }
}
