@preconcurrency import EventKit
import Foundation
import SteadyCore

actor EventKitProvider: CalendarProviding {
    private let store: EKEventStore
    private let steadyCalendarName = "Steady"
    private let calendarIdentifierKey = "steady.calendar.identifier"

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
            .filter { !$0.isAllDay && $0.calendar.title != steadyCalendarName }
            .map { BusyInterval(start: $0.startDate, end: $0.endDate) }
    }

    func commitments(in range: DateRange) throws -> [CalendarCommitment] {
        try requireFullAccess()
        return events(in: range)
            .filter { $0.calendar.title != steadyCalendarName }
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

    func write(_ confirmed: UserConfirmedCalendarWrite) throws -> String {
        try requireFullAccess()
        guard !confirmed.proposal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              confirmed.proposal.end > confirmed.proposal.start else {
            throw CalendarServiceError.invalidProposal
        }
        let calendar = try steadyCalendar()
        let event = EKEvent(eventStore: store)
        event.calendar = calendar
        event.title = confirmed.proposal.title
        event.startDate = confirmed.proposal.start
        event.endDate = confirmed.proposal.end
        event.notes = confirmed.proposal.notes

        do {
            try store.save(event, span: .thisEvent, commit: true)
        } catch {
            throw CalendarServiceError.saveFailed
        }
        guard let identifier = event.eventIdentifier else {
            throw CalendarServiceError.saveFailed
        }
        return identifier
    }

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

