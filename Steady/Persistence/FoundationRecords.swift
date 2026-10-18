import Foundation
import SteadyCore
import SwiftData

/// App preferences are independent of today's responses and system authorization.
@Model
final class FoundationPreferenceRecord {
    @Attribute(.unique) var key: String
    var profileID: UUID
    var sampleData: Bool
    var settingsData: Data
    var quietPeriodsData: Data
    var dismissalCountsData: Data
    var reservationsData: Data
    var nudgesEnabled: Bool
    var confirmedMovementNote: String?
    var updatedAt: Date

    init(key: String, profileID: UUID, sampleData: Bool, at: Date) throws {
        self.key = key
        self.profileID = profileID
        self.sampleData = sampleData
        self.settingsData = try JSONEncoder().encode(FoundationSettings())
        self.quietPeriodsData = try JSONEncoder().encode([NudgeQuietPeriod]())
        self.dismissalCountsData = try JSONEncoder().encode([FoundationKind: Int]())
        self.reservationsData = try JSONEncoder().encode([NudgeReservation]())
        self.nudgesEnabled = false
        self.confirmedMovementNote = nil
        self.updatedAt = at
    }
}

@Model
final class FoundationDayRecord {
    @Attribute(.unique) var key: String
    var profileID: UUID
    var sampleData: Bool
    var day: Date
    var stateData: Data
    var updatedAt: Date

    init(key: String, profileID: UUID, sampleData: Bool, state: FoundationDayState, at: Date) throws {
        self.key = key
        self.profileID = profileID
        self.sampleData = sampleData
        self.day = state.day
        self.stateData = try JSONEncoder().encode(state)
        self.updatedAt = at
    }
}

/// A response identifier is durable so a replayed notification action applies once.
@Model
final class FoundationResponseRecord {
    @Attribute(.unique) var id: String
    var profileID: UUID
    var sampleData: Bool
    var day: Date
    var kindRawValue: String
    var action: String
    var at: Date

    init(id: String, profileID: UUID, sampleData: Bool, day: Date,
         kind: FoundationKind, action: String, at: Date) {
        self.id = id
        self.profileID = profileID
        self.sampleData = sampleData
        self.day = day
        self.kindRawValue = kind.rawValue
        self.action = action
        self.at = at
    }
}
