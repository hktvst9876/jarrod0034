@preconcurrency import EventKit
import Foundation
import SteadyCore

actor EventKitProvider: CalendarProviding {
    let store: EKEventStore
    let steadyCalendarName = "Steady"
    let calendarIdentifierKey = "steady.calendar.identifier"

    init(store: EKEventStore = EKEventStore()) {
        self.store = store
    }

    func accessState() -> CalendarAccessState {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess:
            .fullAccess
        case .notDetermined:
            .notDetermined
        default:
            .denied
        }
    }

    func requestFullAccess() async throws -> CalendarAccessState {
        let allowed = try await store.requestFullAccessToEvents()
        return allowed ? .fullAccess : .denied
    }

    func busyIntervals(in range: DateRange) throws -> [BusyInterval] {
        try requireFullAccess()
        return events(in: range)
            .filter {
                !$0.isAllDay && $0.status != .canceled
                    && $0.calendar.title != steadyCalendarName
            }
            .map { BusyInterval(start: $0.startDate, end: $0.endDate) }
    }

    func commitments(in range: DateRange) throws -> [CalendarCommitment] {
        try requireFullAccess()
        return events(in: range)
            .filter { $0.status != .canceled && $0.calendar.title != steadyCalendarName }
            .map {
                CalendarCommitment(
                    id: $0.eventIdentifier ?? UUID().uuidString,
                    start: $0.startDate,
                    end: $0.endDate,
                    isAllDay: $0.isAllDay,
                    calendarName: $0.calendar.title
                )
            }
    }

    func reschedulingBusyIntervals(in range: DateRange, excluding eventIdentifier: String?) throws -> [BusyInterval] {
        try requireFullAccess()
        return events(in: range).filter {
            !$0.isAllDay && $0.status != .canceled
                && (eventIdentifier == nil || $0.eventIdentifier != eventIdentifier)
        }.map { BusyInterval(start: $0.startDate, end: $0.endDate) }
    }

    func write(_ confirmed: UserConfirmedCalendarWrite) throws -> String {
        guard !DataDeletionGate.shared.isBlocked,
              confirmed.privacyRevision == DataDeletionGate.shared.revision else { throw PrivacyDataError.staleRequest }
        try requireFullAccess()
        let proposal = confirmed.proposal
        try validateProposal(proposal)
        if let savedID = try completedOperation(proposal) { return savedID }
        let existingEvent = try trackedEvent(identifier: proposal.existingEventIdentifier)
        try validateLatestAvailability(proposal, excluding: existingEvent?.eventIdentifier)
        let calendar = try existingEvent?.calendar ?? steadyCalendar()
        let event = existingEvent ?? EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = proposal.title
        event.startDate = proposal.start
        event.endDate = proposal.end
        event.notes = proposal.notes
        event.url = operationURL(proposal.operationID)

        do {
            try store.save(event, span: .thisEvent, commit: true)
        } catch {
            throw CalendarServiceError.saveFailed
        }
        guard let identifier = event.eventIdentifier else {
            throw CalendarServiceError.saveFailed
        }
        UserDefaults.standard.set(identifier, forKey: operationKey(proposal.operationID))
        return identifier
    }

    func eventState(identifier: String) -> CalendarEventState {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            return .unavailable
        }
        guard let event = store.event(withIdentifier: identifier) else { return .missing }
        return isOwned(event) ? .exists : .unavailable
    }

    /// Actor barrier only. User-owned Apple Calendar content is deliberately unchanged.
    func resetLocalState() {}

    private func events(in range: DateRange) -> [EKEvent] {
        let predicate = store.predicateForEvents(
            withStart: range.start,
            end: range.end,
            calendars: nil
        )
        return store.events(matching: predicate)
    }

    private func requireFullAccess() throws {
        guard EKEventStore.authorizationStatus(for: .event) == .fullAccess else {
            throw CalendarServiceError.accessRequired
        }
    }

    private func steadyCalendar() throws -> EKCalendar {
        if let identifier = UserDefaults.standard.string(forKey: calendarIdentifierKey),
           let existing = store.calendar(withIdentifier: identifier),
           existing.title == steadyCalendarName,
           existing.allowsContentModifications {
            return existing
        }
        guard let source = store.sources.first(where: { $0.sourceType == .local })
            ?? store.defaultCalendarForNewEvents?.source else {
            throw CalendarServiceError.calendarSourceUnavailable
        }
        let calendar = EKCalendar(for: .event, eventStore: store)
        calendar.title = steadyCalendarName
        calendar.source = source
        try store.saveCalendar(calendar, commit: true)
        UserDefaults.standard.set(calendar.calendarIdentifier, forKey: calendarIdentifierKey)
        return calendar
    }
}

