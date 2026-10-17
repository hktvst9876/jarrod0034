import Foundation

struct CalendarWriteProposal: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let title: String
    let start: Date
    let end: Date
    let notes: String?
    let existingEventIdentifier: String?
    let operationID: String

    init(
        id: UUID = UUID(), title: String, start: Date, end: Date, notes: String? = nil,
        existingEventIdentifier: String? = nil, operationID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.end = end
        self.notes = notes
        self.existingEventIdentifier = existingEventIdentifier
        self.operationID = operationID ?? id.uuidString
    }
}

/// A distinct type makes every EventKit write pass through a visible confirmation action.
struct UserConfirmedCalendarWrite: Sendable {
    let proposal: CalendarWriteProposal

    private init(proposal: CalendarWriteProposal) {
        self.proposal = proposal
    }

    @MainActor
    static func afterUserTappedConfirm(_ proposal: CalendarWriteProposal) -> Self {
        Self(proposal: proposal)
    }
}

