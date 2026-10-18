import Foundation

/// The single fallback/validation boundary. Optional providers rank only;
/// availability, timeout, fresh context, and cancellation belong to app adapters.
public struct AdvisorCoordinator: Sendable {
    public init() {}

    public func advise(
        alternatives: AlternativeSet, outcome: Outcome, context: AdvisorContext,
        safetyFlags: [SafetyFlag] = [], optionalProvider: (any AdvisorProviding)? = nil
    ) async -> AdvisorDecision {
        if case .pauseRecommendations(let message) = SafetyGate.evaluate(safetyFlags) {
            return .blocked(message)
        }
        guard let request = try? AdvisorPacketBuilder.makeRequest(
            alternatives: alternatives, outcome: outcome, context: context
        ), let baseline = try? await TemplateAdvisor().advise(request) else {
            return .unavailable
        }
        guard let optionalProvider else {
            return selection(baseline, request: request, alternatives: alternatives, source: .template,
                             fallbackReason: .providerUnavailable)
        }
        guard !Task.isCancelled else {
            return selection(baseline, request: request, alternatives: alternatives, source: .template,
                             fallbackReason: .providerFailed)
        }
        let result: AdvisorResult
        do {
            result = try await optionalProvider.advise(request)
        } catch {
            return selection(baseline, request: request, alternatives: alternatives, source: .template,
                             fallbackReason: .providerFailed)
        }
        guard !Task.isCancelled else {
            return selection(baseline, request: request, alternatives: alternatives, source: .template,
                             fallbackReason: .providerFailed)
        }
        do {
            try ResponseValidator.validate(result, for: request)
            // Revalidate canonical data after awaiting an untrusted provider.
            try AlternativeValidator.validate(alternatives.options, for: outcome)
        } catch {
            return selection(baseline, request: request, alternatives: alternatives, source: .template,
                             fallbackReason: .invalidResponse)
        }
        return selection(result, request: request, alternatives: alternatives, source: .onDevice)
    }

    private func selection(
        _ result: AdvisorResult, request: AdvisorRequest, alternatives: AlternativeSet,
        source: AdvisorSource, fallbackReason: AdvisorFallbackReason? = nil
    ) -> AdvisorDecision {
        do { try ResponseValidator.validate(result, for: request) }
        catch { return .unavailable }
        let byID = Dictionary(uniqueKeysWithValues: zip(request.packet.candidates.map(\.id), alternatives.options))
        let ordered = result.rankedCandidateIDs.compactMap { byID[$0] }
        guard ordered.count == alternatives.options.count else { return .unavailable }
        return .ranked(AdvisorSelection(
            alternatives: AlternativeSet(
                planID: alternatives.planID, barrier: alternatives.barrier,
                options: ordered, source: alternatives.source
            ), source: source, fallbackReason: fallbackReason
        ))
    }
}
