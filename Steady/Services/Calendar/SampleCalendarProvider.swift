import Foundation
import SteadyCore

actor SampleCalendarProvider: CalendarProviding {
    private let now: Date
    private var savedEvents: [CalendarWriteProposal] = []

    init(now: Date) {
        self.now = now
    }

    func accessState() -> CalendarAccessState { .fullAccess }
    func requestFullAccess() -> CalendarAccessState { .fullAccess }

    func busyIntervals(in range: DateRange) -> [BusyInterval] {
        sampleCommitments(in: range).map { BusyInterval(start: $0.start, end: $0.end) }
    }

    func commitments(in range: DateRange) -> [CalendarCommitment] {
        sampleCommitments(in: range)
    }

    func write(_ confirmed: UserConfirmedCalendarWrite) throws -> String {
        guard !confirmed.proposal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              confirmed.proposal.end > confirmed.proposal.start else {
            throw CalendarServiceError.invalidProposal
        }
        savedEvents.append(confirmed.proposal)
        return confirmed.proposal.id.uuidString
    }

    private func sampleCommitments(in range: DateRange) -> [CalendarCommitment] {
        var calendar = SteadyCalendar.singapore()
        calendar.locale = Locale(identifier: "en_SG")
        let today = calendar.startOfDay(for: now)
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
