import Foundation

/// Inert data. A proposal has no Calendar or persistence authority.
public struct RescheduleProposal: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let planID: String
    public let title: String
    public let start: Date
    public let end: Date

    public init(id: String, planID: String, title: String, start: Date, end: Date) {
        self.id = id
        self.planID = planID
        self.title = title
        self.start = start
        self.end = end
    }

    public var durationMinutes: Int {
        let minutes = end.timeIntervalSince(start) / 60
        guard minutes.isFinite, minutes > 0, minutes < Double(Int.max) else { return 0 }
        return Int(minutes)
    }
}

public enum RescheduleValidation: String, Codable, Equatable, Sendable {
    case valid
    case invalidTime
    case inThePast
    case calendarConflict
    case safetyBlocked
}
