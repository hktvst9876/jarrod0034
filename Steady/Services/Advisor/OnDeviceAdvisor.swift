import Foundation
import SteadyCore
#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
@Generable
private struct CandidateOrdering: Sendable {
    /// Opaque IDs only. Every other aspect of a card comes from deterministic code.
    var rankedCandidateIDs: [String]
}

@available(iOS 26.0, *)
actor OnDeviceAdvisor: AdvisorProviding {
    func advise(_ request: AdvisorRequest) async throws -> AdvisorResult {
        try Task.checkCancellation()
        guard case .available = SystemLanguageModel.default.availability else {
            throw OnDeviceAdvisorError.unavailable
        }
        try ResponseValidator.validate(AdvisorResult(rankedCandidateIDs: request.packet.candidates.map(\.id)), for: request)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(request.packet)
        guard let packet = String(data: data, encoding: .utf8) else { throw OnDeviceAdvisorError.invalidPacket }
        // No tools, shared transcript, persisted prompt, or action-capable service is supplied.
        let session = LanguageModelSession(instructions: """
            Reorder the provided allowlisted alternatives. Return every opaque candidate ID exactly once.
            Use only the typed facts in the packet. Do not invent facts or infer medical conditions,
            injuries, allergies, diagnoses, or emotions. You cannot change a card, suggest an action,
            or write calendar, notification, preference, or wellness state. Return IDs only.
            """
        )
        let response = try await session.respond(
            to: packet, generating: CandidateOrdering.self,
            options: GenerationOptions(maximumResponseTokens: 128)
        )
        try Task.checkCancellation()
        return AdvisorResult(rankedCandidateIDs: response.content.rankedCandidateIDs)
    }
}

private enum OnDeviceAdvisorError: Error { case unavailable, invalidPacket }
#endif
