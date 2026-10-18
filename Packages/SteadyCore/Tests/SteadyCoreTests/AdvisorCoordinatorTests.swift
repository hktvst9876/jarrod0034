import Foundation
import Testing
@testable import SteadyCore

@Suite("Advisor safety and deterministic fallback")
struct AdvisorCoordinatorTests {
    @Test("TemplateAdvisor works offline and preserves deterministic order")
    func templateIsAlwaysAvailable() async throws {
        let request = try advisorRequest()
        #expect(try await TemplateAdvisor().advise(request).rankedCandidateIDs == request.packet.candidates.map(\.id))
    }

    @Test("Absent optional provider returns canonical template content")
    func absenceFallback() async {
        let alternatives = advisorAlternatives()
        let result = await AdvisorCoordinator().advise(alternatives: alternatives, outcome: advisorOutcome(), context: AdvisorContext())
        guard case .ranked(let selected) = result else { Issue.record("Expected offline fallback"); return }
        #expect(selected.alternatives == alternatives)
        #expect(selected.source == .template && selected.fallbackReason == .providerUnavailable)
    }

    @Test("Provider rejection or failure returns deterministic content without losing functionality")
    func throwingProvider() async {
        let provider = AdvisorSpy(error: true)
        let result = await AdvisorCoordinator().advise(alternatives: advisorAlternatives(), outcome: advisorOutcome(),
                                                      context: AdvisorContext(), optionalProvider: provider)
        guard case .ranked(let selected) = result else { Issue.record("Expected fallback"); return }
        #expect(selected.source == .template && selected.fallbackReason == .providerFailed)
        #expect(selected.alternatives == advisorAlternatives())
        #expect(await provider.calls() == 1)
    }

    @Test("Malformed or extra-field model output falls back unchanged")
    func malformedProvider() async {
        for json in ["broken", "{\"rankedCandidateIDs\":[\"choice_a\",\"choice_b\"],\"action\":\"write\"}"] {
            let provider = AdvisorSpy(json: Data(json.utf8))
            let result = await AdvisorCoordinator().advise(alternatives: advisorAlternatives(), outcome: advisorOutcome(),
                                                          context: AdvisorContext(), optionalProvider: provider)
            guard case .ranked(let selected) = result else { Issue.record("Expected fallback"); return }
            #expect(selected.alternatives == advisorAlternatives() && selected.source == .template)
        }
    }

    @Test("Invalid rankings fall back instead of dropping or inventing options")
    func invalidResponseFallback() async {
        let invalid = [[], ["choice_a"], ["choice_a", "choice_a", "choice_b"],
                       ["choice_a", "choice_b", "outsider"], ["choice_a", "choice_b"]]
        for ids in invalid {
            let provider = AdvisorSpy(result: AdvisorResult(rankedCandidateIDs: ids))
            let result = await AdvisorCoordinator().advise(alternatives: advisorAlternatives(), outcome: advisorOutcome(),
                                                          context: AdvisorContext(), optionalProvider: provider)
            guard case .ranked(let selected) = result else { Issue.record("Expected fallback"); return }
            #expect(selected.source == .template && selected.fallbackReason == .invalidResponse)
            #expect(selected.alternatives == advisorAlternatives())
        }
    }

    @Test("A valid ranking changes only order, never canonical content or source identity")
    func canonicalReconstruction() async {
        let alternatives = advisorAlternatives()
        let provider = AdvisorSpy()
        let result = await AdvisorCoordinator().advise(alternatives: alternatives, outcome: advisorOutcome(),
                                                      context: AdvisorContext(), optionalProvider: provider)
        guard case .ranked(let selected) = result else { Issue.record("Expected ranking"); return }
        #expect(selected.source == .onDevice && selected.fallbackReason == nil)
        #expect(selected.alternatives.options == Array(alternatives.options.reversed()))
        #expect(selected.alternatives.planID == alternatives.planID)
        #expect(selected.alternatives.barrier == alternatives.barrier)
        #expect(selected.alternatives.source == alternatives.source)
    }

    @Test("Safety precedes every provider, even when candidates are malformed")
    func safetyPrecedence() async {
        let provider = AdvisorSpy()
        let empty = AlternativeSet(planID: "bad", barrier: .anotherOption, options: [], source: .fallback)
        let result = await AdvisorCoordinator().advise(alternatives: empty, outcome: advisorOutcome(),
                                                      context: AdvisorContext(), safetyFlags: [.userReported(.pain)], optionalProvider: provider)
        guard case .blocked(let message) = result else { Issue.record("Expected safety gate"); return }
        #expect(message == safetyMessage(for: [.userReported(.pain)]))
        #expect(await provider.calls() == 0)
    }

    @Test("Every supported safety symptom and Health alert prevents optional invocation")
    func allSafetyFlags() async {
        let flags: [SafetyFlag] = [.userReported(.pain), .userReported(.fainting), .userReported(.chestSymptoms),
                                  .userReported(.unusualBreathlessness), .userReported(.feelingUnwell),
                                  .healthAlert(kind: "private alert", at: testDate())]
        for flag in flags {
            let provider = AdvisorSpy()
            let result = await AdvisorCoordinator().advise(alternatives: advisorAlternatives(), outcome: advisorOutcome(),
                                                          context: AdvisorContext(lowDataMode: true), safetyFlags: [flag], optionalProvider: provider)
            guard case .blocked = result else { Issue.record("Expected blocked state"); return }
            #expect(await provider.calls() == 0)
        }
    }

    @Test("Invalid benefit, tradeoff, or partition fails before a provider is called")
    func invalidCanonicalSet() async {
        let bad = [alternativeOption("bad", effort: .minimal, benefit: ""),
                   alternativeOption("bad", effort: .minimal, tradeoff: ""),
                   alternativeOption("bad", effort: .minimal, preserves: [])]
        for first in bad {
            let provider = AdvisorSpy()
            let set = AlternativeSet(planID: "plan", barrier: .anotherOption,
                                     options: [first, alternativeOption("good", effort: .light)], source: .catalog)
            let result = await AdvisorCoordinator().advise(alternatives: set, outcome: advisorOutcome(),
                                                          context: AdvisorContext(), optionalProvider: provider)
            #expect(result == .unavailable)
            #expect(await provider.calls() == 0)
        }
    }

    @Test("Low-data fallback and ranking keep exactly the same deterministic options")
    func lowDataFunctionality() async {
        let set = advisorAlternatives(barrier: .lowEnergy)
        let plain = await AdvisorCoordinator().advise(alternatives: set, outcome: advisorOutcome(), context: AdvisorContext())
        let low = await AdvisorCoordinator().advise(alternatives: set, outcome: advisorOutcome(), context: AdvisorContext(lowDataMode: true))
        #expect(plain == low)
    }

    @Test("Health/recovery differences have no field through which to change template order")
    func noHealthRankingInfluence() async throws {
        let plan = alternativePlan()
        let engine = AlternativeEngine()
        let normal = engine.alternatives(for: plan, barrier: .anotherOption, context: AlternativeContext(recoveryStatus: .normal))
        let recovered = engine.alternatives(for: plan, barrier: .anotherOption, context: AlternativeContext(recoveryStatus: .recovered))
        #expect(normal == recovered)
        guard case .options(let set) = normal else { Issue.record("Expected deterministic candidates"); return }
        let request = try AdvisorPacketBuilder.makeRequest(alternatives: set, outcome: plan.outcome, context: AdvisorContext())
        #expect(try await TemplateAdvisor().advise(request).rankedCandidateIDs == request.packet.candidates.map(\.id))
    }

    @Test("An already-cancelled request never invokes the optional provider")
    func cancellationBeforeInvocation() async {
        let provider = AdvisorSpy()
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await AdvisorCoordinator().advise(
                alternatives: advisorAlternatives(), outcome: advisorOutcome(),
                context: AdvisorContext(), optionalProvider: provider
            )
        }
        let result = await task.value
        guard case .ranked(let selected) = result else { Issue.record("Expected deterministic fallback"); return }
        #expect(selected.alternatives == advisorAlternatives() && selected.source == .template)
        #expect(await provider.calls() == 0)
    }

    @Test("A request cancelled while the provider runs discards its ranking")
    func cancellationAfterInvocation() async {
        let provider = AdvisorSpy(cancelsTask: true)
        let task = Task {
            await AdvisorCoordinator().advise(
                alternatives: advisorAlternatives(), outcome: advisorOutcome(),
                context: AdvisorContext(), optionalProvider: provider
            )
        }
        let result = await task.value
        guard case .ranked(let selected) = result else { Issue.record("Expected deterministic fallback"); return }
        #expect(selected.alternatives == advisorAlternatives() && selected.source == .template)
        #expect(await provider.calls() == 1)
    }

    @Test("Zero, one, or more than three canonical options are unavailable before optional inference")
    func canonicalCountBounds() async {
        let ordinary = advisorAlternatives().options
        for options in [[AlternativeOption](), [ordinary[0]], ordinary + [ordinary[0]]] {
            let provider = AdvisorSpy()
            let set = AlternativeSet(planID: "plan", barrier: .anotherOption, options: options, source: .catalog)
            let result = await AdvisorCoordinator().advise(
                alternatives: set, outcome: advisorOutcome(), context: AdvisorContext(), optionalProvider: provider
            )
            #expect(result == .unavailable)
            #expect(await provider.calls() == 0)
        }
    }

    private func safetyMessage(for flags: [SafetyFlag]) -> SafetyMessage? {
        if case .pauseRecommendations(let message) = SafetyGate.evaluate(flags) { return message }
        return nil
    }
}
