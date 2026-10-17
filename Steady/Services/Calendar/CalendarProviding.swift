import Foundation
import SteadyCore

enum CalendarAccessState: Sendable, Equatable {
    case notDetermined
    case denied
    case fullAccess
}

enum CalendarEventState: Sendable, Equatable {
    case exists
    case missing
    case unavailable
}

protocol CalendarProviding: Sendable {
    func accessState() async -> CalendarAccessState
    func requestFullAccess() async throws -> CalendarAccessState
    func busyIntervals(in range: DateRange) async throws -> [BusyInterval]
    func commitments(in range: DateRange) async throws -> [CalendarCommitment]
    func reschedulingBusyIntervals(in range: DateRange, excluding eventIdentifier: String?) async throws -> [BusyInterval]
    func write(_ confirmed: UserConfirmedCalendarWrite) async throws -> String
    func eventState(identifier: String) async -> CalendarEventState
}

enum CalendarServiceError: LocalizedError {
    case accessRequired
    case calendarSourceUnavailable
    case invalidProposal
    case saveFailed
    case slotUnavailable
    case eventMissing
    case eventNotOwned

    var errorDescription: String? {
        switch self {
        case .accessRequired:
            "Calendar access is off. You can enter your free time manually."
        case .calendarSourceUnavailable:
            "Steady could not find a calendar account for its own events."
        case .invalidProposal:
            "The proposed calendar time is not valid. Nothing was changed."
        case .saveFailed:
            "Calendar could not confirm the save. Keep this proposal and retry to check its result."
        case .slotUnavailable:
            "Your calendar has changed and this time no longer fits. Choose another time."
        case .eventMissing:
            "This event was removed from Calendar. Steady will keep the plan unscheduled."
        case .eventNotOwned:
            "This event is no longer in Steady's own calendar. Steady will not change it."
        }
    }
}

