import Foundation

/// Required offline provider. Preserves the deterministic engine's order, and
/// cannot intensify, rewrite, omit, persist, or execute anything.
public struct TemplateAdvisor: AdvisorProviding {
    public init() {}

    public func advise(_ request: AdvisorRequest) async throws -> AdvisorResult {
        let result = AdvisorResult(rankedCandidateIDs: request.packet.candidates.map(\.id))
        try ResponseValidator.validate(result, for: request)
        return result
    }
}
