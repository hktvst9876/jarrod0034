import Foundation

public enum WeeklyLearningError: String, Error, Codable, Equatable, Sendable {
    case emptyID, staleScope, staleWeek, expired, invalidProposal, changedBaseValue
    case invalidDates, overlappingExperiment, conflictingID
}

public struct WeeklyDefaultProposal: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let scope: WeeklyScope
    public let baseExamMode: Bool
    public let proposedExamMode: Bool
    public let issuedAt: Date
    public let expiresAt: Date
    public let evidencePlanIDs: [String]
    public let evidenceChangedDays: Int
    public let reason: String

    public init(id: String, scope: WeeklyScope, baseExamMode: Bool, proposedExamMode: Bool,
                issuedAt: Date, expiresAt: Date, evidencePlanIDs: [String], evidenceChangedDays: Int, reason: String) {
        self.id = id
        self.scope = scope
        self.baseExamMode = baseExamMode
        self.proposedExamMode = proposedExamMode
        self.issuedAt = issuedAt
        self.expiresAt = expiresAt
        self.evidencePlanIDs = evidencePlanIDs
        self.evidenceChangedDays = evidenceChangedDays
        self.reason = reason
    }
}

public enum WeeklyDefaultApproval: Codable, Equatable, Sendable {
    case applyExamMode(Bool)
    case alreadyApplied
}

public enum WeeklyDefaultEngine {
    public static func proposal(
        id: String, summary: WeeklySummary, currentExamMode: Bool, now: Date,
        calendar: Calendar = SteadyCalendar.singapore()
    ) -> WeeklyDefaultProposal? {
        guard !id.isEmpty, !currentExamMode, (3...7).contains(summary.changedPlanDays),
              summary.scope.weekStart == summary.window.start, !summary.evidenceChangedPlanIDs.isEmpty,
              now.timeIntervalSinceReferenceDate.isFinite, summary.window.observedThrough <= now,
              !summary.scope.revision.isEmpty,
              let expiry = calendar.date(byAdding: .minute, value: 30, to: now) else { return nil }
        return WeeklyDefaultProposal(
            id: id, scope: summary.scope, baseExamMode: false, proposedExamMode: true,
            issuedAt: now, expiresAt: expiry, evidencePlanIDs: summary.evidenceChangedPlanIDs,
            evidenceChangedDays: summary.changedPlanDays,
            reason: "Saved plans were adapted on several days. You can choose exam mode to keep planning lighter; nothing changes without approval."
        )
    }
}

public enum WeeklyApprovalReducer {
    public static func confirm(
        _ proposal: WeeklyDefaultProposal, currentScope: WeeklyScope, currentExamMode: Bool,
        appliedProposalIDs: Set<String>, now: Date, calendar: Calendar = SteadyCalendar.singapore()
    ) throws -> WeeklyDefaultApproval {
        guard !proposal.id.isEmpty else { throw WeeklyLearningError.emptyID }
        guard proposal.scope == currentScope, !currentScope.revision.isEmpty else { throw WeeklyLearningError.staleScope }
        if appliedProposalIDs.contains(proposal.id) { return .alreadyApplied }
        try WeeklyFreshness.validate(preparedAt: proposal.issuedAt, now: now, calendar: calendar)
        guard proposal.expiresAt >= now, proposal.expiresAt > proposal.issuedAt,
              proposal.expiresAt.timeIntervalSince(proposal.issuedAt) <= 1_800 else { throw WeeklyLearningError.expired }
        guard !proposal.baseExamMode, proposal.proposedExamMode,
              proposal.evidenceChangedDays >= 3, proposal.evidenceChangedDays <= 7,
              !proposal.evidencePlanIDs.isEmpty,
              !proposal.evidencePlanIDs.contains(where: \.isEmpty),
              Set(proposal.evidencePlanIDs).count == proposal.evidencePlanIDs.count else { throw WeeklyLearningError.invalidProposal }
        guard currentExamMode == proposal.baseExamMode else { throw WeeklyLearningError.changedBaseValue }
        return .applyExamMode(true)
    }
}

enum WeeklyFreshness {
    static func validate(preparedAt: Date, now: Date, calendar: Calendar) throws {
        guard preparedAt.timeIntervalSinceReferenceDate.isFinite, now.timeIntervalSinceReferenceDate.isFinite,
              preparedAt <= now, now.timeIntervalSince(preparedAt) <= 1_800 else { throw WeeklyLearningError.expired }
        guard let issuedWeek = WeeklyWindow.make(containing: preparedAt, now: preparedAt, calendar: calendar),
              let currentWeek = WeeklyWindow.make(containing: now, now: now, calendar: calendar),
              issuedWeek.start == currentWeek.start else { throw WeeklyLearningError.staleWeek }
        guard calendar.isDate(preparedAt, inSameDayAs: now) else { throw WeeklyLearningError.staleScope }
    }
}
