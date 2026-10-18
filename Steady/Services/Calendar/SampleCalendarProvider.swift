import Foundation
import SteadyCore

actor SampleCalendarProvider: CalendarProviding {
    private let clock: any SteadyCore.Clock
    private var savedEvents: [CalendarWriteProposal] = []
    private var savedOperationIDs: [String: String] = [:]
    private let eventsKey = "steady.sample.calendar.events"
    private let operationsKey = "steady.sample.calendar.operations"

    init(clock: any SteadyCore.Clock) {
        self.clock = clock
        if let data = UserDefaults.standard.data(forKey: "steady.sample.calendar.events"),
           let events = try? JSONDecoder().decode([CalendarWriteProposal].self, from: data) {
            savedEvents = events
        }
        savedOperationIDs = UserDefaults.standard.dictionary(forKey: "steady.sample.calendar.operations") as? [String: String] ?? [:]
    }

    func accessState() -> CalendarAccessState { .fullAccess }
    func requestFullAccess() -> CalendarAccessState { .fullAccess }

    func busyIntervals(in range: DateRange) -> [BusyInterval] {
        sampleCommitments(in: range).map { BusyInterval(start: $0.start, end: $0.end) }
    }

    func commitments(in range: DateRange) -> [CalendarCommitment] {
        sampleCommitments(in: range)
    }

    func reschedulingBusyIntervals(in range: DateRange, excluding eventIdentifier: String?) -> [BusyInterval] {
        sampleCommitments(in: range).map { BusyInterval(start: $0.start, end: $0.end) }
            + savedEvents.filter {
                $0.id.uuidString != eventIdentifier && $0.end > range.start && $0.start < range.end
            }.map { BusyInterval(start: $0.start, end: $0.end) }
    }

    func write(_ confirmed: UserConfirmedCalendarWrite) throws -> String {
        guard !DataDeletionGate.shared.isBlocked,
              confirmed.privacyRevision == DataDeletionGate.shared.revision else { throw PrivacyDataError.staleRequest }
        guard !confirmed.proposal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              confirmed.proposal.end > confirmed.proposal.start,
              !confirmed.proposal.operationID.isEmpty else {
            throw CalendarServiceError.invalidProposal
        }
        let proposal = confirmed.proposal
        if let existingID = savedOperationIDs[proposal.operationID] {
            guard let saved = savedEvents.first(where: { $0.id.uuidString == existingID }) else {
                throw CalendarServiceError.eventMissing
            }
            guard saved.start == proposal.start, saved.end == proposal.end, saved.title == proposal.title else {
                throw CalendarServiceError.invalidProposal
            }
            return existingID
        }
        if let identifier = proposal.existingEventIdentifier {
            guard savedEvents.contains(where: { $0.id.uuidString == identifier }) else {
                throw CalendarServiceError.eventMissing
            }
        }
        let busy = sampleCommitments(in: DateRange(
            start: proposal.start.addingTimeInterval(-15 * 60),
            end: proposal.end.addingTimeInterval(15 * 60)
        ))
            .map { BusyInterval(start: $0.start, end: $0.end) }
            + savedEvents.filter { $0.id.uuidString != proposal.existingEventIdentifier }
                .map { BusyInterval(start: $0.start, end: $0.end) }
        let value = RescheduleProposal(
            id: proposal.operationID, planID: "", title: proposal.title,
            start: proposal.start, end: proposal.end
        )
        guard ReschedulePlanner.validate(value, now: clock.now, busyIntervals: busy) == .valid else {
            throw CalendarServiceError.slotUnavailable
        }
        let id = proposal.existingEventIdentifier ?? proposal.id.uuidString
        savedEvents.removeAll { $0.id.uuidString == id }
        let stored = CalendarWriteProposal(
            id: UUID(uuidString: id) ?? proposal.id, title: proposal.title,
            start: proposal.start, end: proposal.end, notes: proposal.notes,
            existingEventIdentifier: proposal.existingEventIdentifier, operationID: proposal.operationID
        )
        savedEvents.append(stored)
        savedOperationIDs[proposal.operationID] = id
        if let data = try? JSONEncoder().encode(savedEvents) {
            UserDefaults.standard.set(data, forKey: eventsKey)
            UserDefaults.standard.set(savedOperationIDs, forKey: operationsKey)
        }
        return id
    }

    func eventState(identifier: String) -> CalendarEventState {
        savedEvents.contains { $0.id.uuidString == identifier } ? .exists : .missing
    }

    func resetLocalState() {
        savedEvents = []
        savedOperationIDs = [:]
        UserDefaults.standard.removeObject(forKey: eventsKey)
        UserDefaults.standard.removeObject(forKey: operationsKey)
    }

    private func sampleCommitments(in range: DateRange) -> [CalendarCommitment] {
        var calendar = SteadyCalendar.singapore()
        calendar.locale = Locale(identifier: "en_SG")
        let today = calendar.startOfDay(for: clock.now)
        let offsetsAndHours = [(0, 10, 0, 90), (0, 14, 0, 120), (1, 8, 30, 90)]

        let samples = offsetsAndHours.compactMap { item -> CalendarCommitment? in
            let (dayOffset, hour, minute, duration) = item
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: today),
                  let start = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day),
                  let end = calendar.date(byAdding: .minute, value: duration, to: start) else {
                return nil
            }
            return CalendarCommitment(
                id: "sample-\(dayOffset)-\(hour)",
                start: start,
                end: end,
                isAllDay: false,
                calendarName: "Sample timetable"
            )
        }

        return samples.filter { $0.end > range.start && $0.start < range.end }
    }
}
