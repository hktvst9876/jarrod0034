@preconcurrency import EventKit
import Foundation
import SteadyCore

extension EventKitProvider {
    func validateProposal(_ proposal: CalendarWriteProposal) throws {
        guard !proposal.operationID.isEmpty,
              proposal.operationID.count <= 512,
              !proposal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              proposal.start.timeIntervalSinceReferenceDate.isFinite,
              proposal.end.timeIntervalSinceReferenceDate.isFinite,
              proposal.end > proposal.start else {
            throw CalendarServiceError.invalidProposal
        }
    }

    func operationKey(_ operationID: String) -> String {
        "steady.calendar.operation." + operationID
    }

    func operationURL(_ operationID: String) -> URL? {
        var components = URLComponents()
        components.scheme = "steady"
        components.host = "calendar-operation"
        components.path = "/" + operationID
        return components.url
    }

    func isOwned(_ event: EKEvent) -> Bool {
        guard let calendarID = UserDefaults.standard.string(forKey: calendarIdentifierKey) else {
            return false
        }
        return event.calendar.calendarIdentifier == calendarID
            && event.calendar.title == steadyCalendarName
            && event.calendar.allowsContentModifications
    }

    func trackedEvent(identifier: String?) throws -> EKEvent? {
        guard let identifier else { return nil }
        guard let event = store.event(withIdentifier: identifier) else {
            throw CalendarServiceError.eventMissing
        }
        guard isOwned(event) else { throw CalendarServiceError.eventNotOwned }
        return event
    }

    /// Stored operation IDs make retries safe even if local plan persistence failed.
    func completedOperation(_ proposal: CalendarWriteProposal) throws -> String? {
        if let eventID = UserDefaults.standard.string(forKey: operationKey(proposal.operationID)) {
            guard let event = try trackedEvent(identifier: eventID) else { return nil }
            guard matches(event, proposal: proposal) else { throw CalendarServiceError.invalidProposal }
            return eventID
        }
        // Recover if EventKit saved but the process ended before the identifier was cached.
        guard let calendarID = UserDefaults.standard.string(forKey: calendarIdentifierKey),
              let calendar = store.calendar(withIdentifier: calendarID),
              calendar.title == steadyCalendarName,
              let marker = operationURL(proposal.operationID) else { return nil }
        let predicate = store.predicateForEvents(withStart: proposal.start, end: proposal.end, calendars: [calendar])
        if let event = store.events(matching: predicate).first(where: { $0.url == marker }) {
            guard isOwned(event), matches(event, proposal: proposal),
                  let identifier = event.eventIdentifier else {
                throw CalendarServiceError.eventNotOwned
            }
            UserDefaults.standard.set(identifier, forKey: operationKey(proposal.operationID))
            return identifier
        }
        return nil
    }

    func validateLatestAvailability(_ proposal: CalendarWriteProposal, excluding eventID: String?) throws {
        let padding: TimeInterval = 15 * 60
        let predicate = store.predicateForEvents(
            withStart: proposal.start.addingTimeInterval(-padding),
            end: proposal.end.addingTimeInterval(padding), calendars: nil
        )
        let busy = store.events(matching: predicate).filter {
            !$0.isAllDay && $0.status != .canceled
                && (eventID == nil || $0.eventIdentifier != eventID)
        }.map { BusyInterval(start: $0.startDate, end: $0.endDate) }
        let value = RescheduleProposal(
            id: proposal.operationID, planID: "", title: proposal.title,
            start: proposal.start, end: proposal.end
        )
        switch ReschedulePlanner.validate(value, now: Date(), busyIntervals: busy) {
        case .valid: return
        case .calendarConflict: throw CalendarServiceError.slotUnavailable
        default: throw CalendarServiceError.invalidProposal
        }
    }

    private func matches(_ event: EKEvent, proposal: CalendarWriteProposal) -> Bool {
        event.title == proposal.title
            && abs(event.startDate.timeIntervalSince(proposal.start)) < 1
            && abs(event.endDate.timeIntervalSince(proposal.end)) < 1
    }
}
