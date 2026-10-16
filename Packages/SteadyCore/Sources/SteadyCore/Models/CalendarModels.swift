import Foundation

public struct DateRange: Codable, Equatable, Sendable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }

    public var durationMinutes: Int {
        guard end > start else { return 0 }
        return Int(end.timeIntervalSince(start) / 60)
    }
}

public struct BusyInterval: Codable, Equatable, Sendable {
    public let start: Date
    public let end: Date

    public init(start: Date, end: Date) {
        self.start = start
        self.end = end
    }
}

public enum SlotConfidence: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case calendarDerived
    case manual
    case unknown
}

public struct FreeSlot: Codable, Equatable, Sendable {
    public let start: Date
    public let end: Date
    public let travelAllowanceMinutes: Int
    public let confidence: SlotConfidence

    public init(
        start: Date,
        end: Date,
        travelAllowanceMinutes: Int = 0,
        confidence: SlotConfidence
    ) {
        self.start = start
        self.end = end
        self.travelAllowanceMinutes = max(0, travelAllowanceMinutes)
        self.confidence = confidence
    }

    public var durationMinutes: Int {
        guard end > start else { return 0 }
        return Int(end.timeIntervalSince(start) / 60)
    }
}

public enum AvailabilitySource: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case calendar
    case manualMinutes
    case manualBlocks
    case unknown
}

public struct Availability: Codable, Equatable, Sendable {
    public let source: AvailabilitySource
    public let freeSlots: [FreeSlot]
    public let freeMinutesToday: Int?
    public let firstCommitmentTomorrow: Date?

    public init(
        source: AvailabilitySource,
        freeSlots: [FreeSlot],
        freeMinutesToday: Int?,
        firstCommitmentTomorrow: Date?
    ) {
        self.source = source
        self.freeSlots = freeSlots
        self.freeMinutesToday = freeMinutesToday.map { max(0, $0) }
        self.firstCommitmentTomorrow = firstCommitmentTomorrow
    }

    public static let unknown = Availability(
        source: .unknown,
        freeSlots: [],
        freeMinutesToday: nil,
        firstCommitmentTomorrow: nil
    )
}

public struct CalendarCommitment: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let start: Date
    public let end: Date
    public let isAllDay: Bool
    public let calendarName: String

    public init(
        id: String,
        start: Date,
        end: Date,
        isAllDay: Bool,
        calendarName: String
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.isAllDay = isAllDay
        self.calendarName = calendarName
    }
}
