import Foundation

public enum WeeklyHelpfulness: String, Codable, CaseIterable, Hashable, Sendable {
    case helpful, mixed, notHelpful
}

public enum WeeklyMetricKind: String, Codable, Equatable, Sendable {
    case suggestionShown, suggestionAccepted, alternativeCompleted, foodShown, foodCorrection, helpfulness
}

/// Explicit local telemetry only. subjectID links a response to its recorded exposure.
public struct WeeklyMetricEvent: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let at: Date
    public let kind: WeeklyMetricKind
    public let subjectID: String
    public let decisionSeconds: Double?
    public let helpfulness: WeeklyHelpfulness?

    public init(
        id: String, at: Date, kind: WeeklyMetricKind, subjectID: String,
        decisionSeconds: Double? = nil, helpfulness: WeeklyHelpfulness? = nil
    ) {
        self.id = id
        self.at = at
        self.kind = kind
        self.subjectID = subjectID
        self.decisionSeconds = decisionSeconds
        self.helpfulness = helpfulness
    }
}

public struct WeeklyMetricSummary: Codable, Equatable, Sendable {
    public let suggestionsShown: Int?
    public let suggestionsAccepted: Int?
    public let alternativesCompleted: Int?
    public let meanDecisionSeconds: Double?
    public let decisionTimeSamples: Int
    public let foodExposures: Int?
    public let correctedFoodExposures: Int?
    public let correctionRate: Double?
    public let helpfulResponses: Int
    public let mixedResponses: Int
    public let notHelpfulResponses: Int
    public let helpfulnessFraction: Double?
}

public enum WeeklyMetricAggregator {
    public static func summarize(_ events: [WeeklyMetricEvent], window: WeeklyWindow) -> WeeklyMetricSummary {
        let valid = events.filter { !$0.id.isEmpty && !$0.subjectID.isEmpty && window.contains($0.at) }
        let groups = Dictionary(grouping: valid, by: \.id)
        // Conflicting duplicates are not evidence; discard the ID rather than depend on input order.
        let unique = groups.values.compactMap { group -> WeeklyMetricEvent? in
            guard let first = group.first, group.count == 1 || group.allSatisfy({ $0 == first }) else { return nil }
            return first
        }
        let shown = bySubject(unique, kind: .suggestionShown)
        let foodShown = bySubject(unique, kind: .foodShown)
        let accepted = bySubject(unique, kind: .suggestionAccepted).filter { subject, event in
            shown[subject].map { $0.at <= event.at } ?? false
        }
        let completed = bySubject(unique, kind: .alternativeCompleted).filter { subject, event in
            accepted[subject].map { $0.at <= event.at } ?? false
        }
        let corrected = bySubject(unique, kind: .foodCorrection).filter { subject, event in
            foodShown[subject].map { $0.at <= event.at } ?? false
        }
        let times = accepted.values.compactMap { event -> Double? in
            guard let seconds = event.decisionSeconds, seconds.isFinite, (0...86_400).contains(seconds),
                  let exposure = shown[event.subjectID], seconds <= event.at.timeIntervalSince(exposure.at) + 1 else { return nil }
            return seconds
        }
        let helpfulness = bySubject(unique, kind: .helpfulness).values.compactMap(\.helpfulness)
        let helpful = helpfulness.filter { $0 == .helpful }.count
        let mixed = helpfulness.filter { $0 == .mixed }.count
        let notHelpful = helpfulness.filter { $0 == .notHelpful }.count
        return WeeklyMetricSummary(
            suggestionsShown: shown.isEmpty ? nil : shown.count,
            suggestionsAccepted: shown.isEmpty ? nil : accepted.count,
            alternativesCompleted: accepted.isEmpty ? nil : completed.count,
            meanDecisionSeconds: times.isEmpty ? nil : times.reduce(0, +) / Double(times.count),
            decisionTimeSamples: times.count, foodExposures: foodShown.isEmpty ? nil : foodShown.count,
            correctedFoodExposures: foodShown.isEmpty ? nil : corrected.count,
            correctionRate: foodShown.isEmpty ? nil : Double(corrected.count) / Double(foodShown.count),
            helpfulResponses: helpful, mixedResponses: mixed, notHelpfulResponses: notHelpful,
            helpfulnessFraction: helpfulness.isEmpty ? nil : Double(helpful) / Double(helpfulness.count)
        )
    }

    private static func bySubject(_ events: [WeeklyMetricEvent], kind: WeeklyMetricKind) -> [String: WeeklyMetricEvent] {
        var result: [String: WeeklyMetricEvent] = [:]
        for event in events.filter({ $0.kind == kind }).sorted(by: { $0.at == $1.at ? $0.id < $1.id : $0.at < $1.at }) {
            if result[event.subjectID] == nil { result[event.subjectID] = event }
        }
        return result
    }
}
