import Foundation
import SteadyCore

enum CalendarAccessState: Sendable, Equatable {
    case notDetermined
    case denied
    case fullAccess
}

protocol CalendarProviding: Sendable {
    func accessState() async -> CalendarAccessState
    func requestFullAccess() async throws -> CalendarAccessState
    func busyIntervals(in range: DateRange) async throws -> [BusyInterval]
    func commitments(in range: DateRange) async throws -> [CalendarCommitment]
    func write(_ confirmed: UserConfirmedCalendarWrite) async throws -> String
}

enum CalendarServiceError: LocalizedError {
    case accessRequired
    case calendarSourceUnavailable
    case invalidProposal
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .accessRequired:
            "Calendar access is off. You can enter your free time manually."
        case .calendarSourceUnavailable:
            "Steady could not find a calendar account for its own events."
        case .invalidProposal:
            "The proposed calendar time is not valid. Nothing was changed."
        case .saveFailed:
            "The event could not be added. Nothing was changed."
        }
    }
}

