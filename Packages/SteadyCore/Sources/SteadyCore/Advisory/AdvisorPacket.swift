import Foundation

public enum AdvisorTimeBudget: String, Codable, Equatable, Sendable {
    case unknown, underFiveMinutes, fiveToTenMinutes, elevenToTwentyMinutes, overTwentyMinutes
}

/// A read-only candidate contract, with opaque request-local identifiers.
/// Intentionally excludes titles, benefit/tradeoff prose, steps, and stored IDs.
public struct AdvisorCandidate: Encodable, Equatable, Sendable {
    public let id: String
    public let planType: PlanType
    public let minutes: Int
    public let effort: AlternativeEffort
    public let preserves: [OutcomePart]
    public let doesNotPreserve: [OutcomePart]
}

/// A typed read-only coarse-context contract, never an unrestricted dictionary.
public struct AdvisorCoarseContext: Encodable, Equatable, Sendable {
    public let timeBudget: AdvisorTimeBudget
    public let barrier: AlternativeBarrier?
    public let lowDataMode: Bool
}

public struct AdvisorPacket: Encodable, Equatable, Sendable {
    public let schemaVersion: Int
    public let candidates: [AdvisorCandidate]
    public let context: AdvisorCoarseContext
}

public struct AdvisorRequest: Encodable, Equatable, Sendable {
    public let packet: AdvisorPacket

    public init(packet: AdvisorPacket) { self.packet = packet }
}

public enum AdvisorPacketBuilder {
    /// Accept only an already-filtered deterministic set and typed context.
    /// Safety flags are deliberately not accepted or serialised by this builder.
    public static func makeRequest(
        alternatives: AlternativeSet, outcome: Outcome, context: AdvisorContext
    ) throws -> AdvisorRequest {
        do {
            try AlternativeValidator.validate(alternatives.options, for: outcome)
        } catch {
            throw AdvisorValidationError.invalidCandidates
        }
        let aliases = ["choice_a", "choice_b", "choice_c"]
        let candidates = alternatives.options.enumerated().map { index, option in
            AdvisorCandidate(
                id: aliases[index], planType: option.planType, minutes: option.minutes,
                effort: option.effort,
                preserves: option.preserves.sorted { $0.rawValue < $1.rawValue },
                doesNotPreserve: option.doesNotPreserve.sorted { $0.rawValue < $1.rawValue }
            )
        }
        let coarse = AdvisorCoarseContext(
            timeBudget: timeBudget(context.availableMinutes),
            barrier: context.lowDataMode ? nil : alternatives.barrier,
            lowDataMode: context.lowDataMode
        )
        return AdvisorRequest(packet: AdvisorPacket(schemaVersion: 1, candidates: candidates, context: coarse))
    }

    private static func timeBudget(_ minutes: Int?) -> AdvisorTimeBudget {
        guard let minutes else { return .unknown }
        switch minutes {
        case ..<5: return .underFiveMinutes
        case 5...10: return .fiveToTenMinutes
        case 11...20: return .elevenToTwentyMinutes
        default: return .overTwentyMinutes
        }
    }
}
