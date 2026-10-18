import Foundation

/// This is the only provider boundary. Providers receive no persistence models,
/// safety details, Calendar records, or authority to execute an action.
public protocol AdvisorProviding: Sendable {
    func advise(_ request: AdvisorRequest) async throws -> AdvisorResult
}

public struct AdvisorContext: Equatable, Sendable {
    public let availableMinutes: Int?
    public let lowDataMode: Bool

    public init(
        availableMinutes: Int? = nil, lowDataMode: Bool = false
    ) {
        self.availableMinutes = availableMinutes.map { max(0, $0) }
        self.lowDataMode = lowDataMode
    }
}

public enum AdvisorSource: String, Codable, Equatable, Sendable {
    case template, onDevice
}

public enum AdvisorFallbackReason: String, Codable, Equatable, Sendable {
    case providerUnavailable, providerFailed, invalidResponse
}

public struct AdvisorSelection: Equatable, Sendable {
    public let alternatives: AlternativeSet
    public let source: AdvisorSource
    public let fallbackReason: AdvisorFallbackReason?

    public init(
        alternatives: AlternativeSet, source: AdvisorSource,
        fallbackReason: AdvisorFallbackReason? = nil
    ) {
        self.alternatives = alternatives
        self.source = source
        self.fallbackReason = fallbackReason
    }
}

public enum AdvisorDecision: Equatable, Sendable {
    case ranked(AdvisorSelection)
    case blocked(SafetyMessage)
    case unavailable
}

public enum AdvisorValidationError: Error, Equatable, Sendable {
    case invalidCandidates
    case invalidPacket
    case invalidOptionCount
    case duplicateCandidateID
    case notAFullPermutation
    case unexpectedResponseFields
}

/// Output has no prose, factual claims, citations, inferred personal attributes,
/// or executable/tool fields. Unknown JSON fields fail closed, not silently drop.
public struct AdvisorResult: Codable, Equatable, Sendable {
    public let rankedCandidateIDs: [String]

    public init(rankedCandidateIDs: [String]) {
        self.rankedCandidateIDs = rankedCandidateIDs
    }

    private struct Key: CodingKey {
        let stringValue: String
        let intValue: Int? = nil
        init?(stringValue: String) { self.stringValue = stringValue }
        init?(intValue: Int) { return nil }
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: Key.self)
        guard container.allKeys.map(\.stringValue) == ["rankedCandidateIDs"],
              let key = Key(stringValue: "rankedCandidateIDs") else {
            throw AdvisorValidationError.unexpectedResponseFields
        }
        rankedCandidateIDs = try container.decode([String].self, forKey: key)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: Key.self)
        guard let key = Key(stringValue: "rankedCandidateIDs") else {
            throw AdvisorValidationError.unexpectedResponseFields
        }
        try container.encode(rankedCandidateIDs, forKey: key)
    }

    public static func decode(_ data: Data) throws -> AdvisorResult {
        try JSONDecoder().decode(AdvisorResult.self, from: data)
    }
}
