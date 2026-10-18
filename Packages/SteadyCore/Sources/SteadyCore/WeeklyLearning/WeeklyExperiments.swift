import Foundation

public struct WeeklyReview: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let scope: WeeklyScope
    public let reviewedAt: Date
    public let helpfulness: WeeklyHelpfulness?

    public init(id: String, scope: WeeklyScope, reviewedAt: Date, helpfulness: WeeklyHelpfulness? = nil) {
        self.id = id
        self.scope = scope
        self.reviewedAt = reviewedAt
        self.helpfulness = helpfulness
    }
}

public enum WeeklyExperimentKind: String, Codable, CaseIterable, Hashable, Sendable {
    case smallPlan, windDown, quietFoundation

    public var title: String {
        switch self {
        case .smallPlan: "Try a smaller plan"
        case .windDown: "Try a small wind-down"
        case .quietFoundation: "Try a quiet Foundation"
        }
    }

    public var simpleMeasure: String {
        switch self {
        case .smallPlan: "At the next review, say whether a smaller self-chosen plan was useful."
        case .windDown: "At the next review, say whether a brief optional wind-down was useful."
        case .quietFoundation: "At the next review, say whether one quiet self-chosen Foundation was useful."
        }
    }
}

public struct WeeklyExperimentDraft: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let scope: WeeklyScope
    public let kind: WeeklyExperimentKind
    public let start: Date
    public let endExclusive: Date
    public let preparedAt: Date

    public init(id: String, scope: WeeklyScope, kind: WeeklyExperimentKind, start: Date,
                endExclusive: Date, preparedAt: Date) {
        self.id = id
        self.scope = scope
        self.kind = kind
        self.start = start
        self.endExclusive = endExclusive
        self.preparedAt = preparedAt
    }
}

public struct WeeklyExperiment: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let scope: WeeklyScope
    public let kind: WeeklyExperimentKind
    public let start: Date
    public let endExclusive: Date
    public let createdAt: Date

    public init(id: String, scope: WeeklyScope, kind: WeeklyExperimentKind, start: Date, endExclusive: Date, createdAt: Date) {
        self.id = id
        self.scope = scope
        self.kind = kind
        self.start = start
        self.endExclusive = endExclusive
        self.createdAt = createdAt
    }
}

public enum WeeklyExperimentReducer {
    public static func save(
        _ draft: WeeklyExperimentDraft, currentScope: WeeklyScope, existing: WeeklyExperiment?,
        now: Date, calendar: Calendar = SteadyCalendar.singapore()
    ) throws -> WeeklyExperiment {
        guard !draft.id.isEmpty else { throw WeeklyLearningError.emptyID }
        guard draft.scope == currentScope, !currentScope.revision.isEmpty else { throw WeeklyLearningError.staleScope }
        try WeeklyFreshness.validate(preparedAt: draft.preparedAt, now: now, calendar: calendar)
        guard draft.start.timeIntervalSinceReferenceDate.isFinite, draft.endExclusive.timeIntervalSinceReferenceDate.isFinite,
              draft.start == calendar.startOfDay(for: draft.start),
              draft.endExclusive == calendar.startOfDay(for: draft.endExclusive),
              draft.start >= calendar.startOfDay(for: now),
              let latestStart = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: now)),
              draft.start <= latestStart,
              let days = calendar.dateComponents([.day], from: draft.start, to: draft.endExclusive).day,
              (2...14).contains(days) else { throw WeeklyLearningError.invalidDates }
        if let existing {
            if existing.id == draft.id {
                guard existing.scope == draft.scope, existing.kind == draft.kind,
                      existing.start == draft.start, existing.endExclusive == draft.endExclusive else {
                    throw WeeklyLearningError.conflictingID
                }
                return existing
            }
            if existing.endExclusive > now { throw WeeklyLearningError.overlappingExperiment }
        }
        return WeeklyExperiment(id: draft.id, scope: draft.scope, kind: draft.kind,
                                start: draft.start, endExclusive: draft.endExclusive, createdAt: now)
    }

    public static func cancel(
        _ experiment: WeeklyExperiment, capturedScope: WeeklyScope, currentScope: WeeklyScope,
        preparedAt: Date, now: Date,
        calendar: Calendar = SteadyCalendar.singapore()
    ) throws {
        guard !experiment.id.isEmpty else { throw WeeklyLearningError.emptyID }
        // The current scope is captured by the cancel confirmation, not the original experiment's old revision.
        guard capturedScope == currentScope, experiment.scope.profileID == currentScope.profileID,
              experiment.scope.isSample == currentScope.isSample,
              !currentScope.revision.isEmpty else { throw WeeklyLearningError.staleScope }
        try WeeklyFreshness.validate(preparedAt: preparedAt, now: now, calendar: calendar)
    }
}
