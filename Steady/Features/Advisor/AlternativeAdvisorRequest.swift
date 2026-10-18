import Foundation
import SteadyCore

/// Local freshness snapshot only. It is never encoded or passed to a provider.
@MainActor
struct AlternativeAdvisorRequest {
    let generation: UUID
    let preferenceRevision: UUID
    let day: Date
    let profile: Profile?
    let movementNote: String
    let sample: Bool
    let source: PlanItem
    let options: AlternativeSet
    let movementMode: AlternativeMovementMode
    let avoids: Set<AlternativeMovement>
    let loadID: UUID

    func isCurrent(model: AlternativesViewModel, profile record: ProfileRecord,
                   sample currentSample: Bool, store: PlanStore, environment: AppEnvironment) -> Bool {
        guard generation == model.orderingGeneration, !model.orderingFrozen,
              preferenceRevision == environment.advisor.revision,
              environment.advisor.isEnabled(profileID: record.id, sample: currentSample),
              !currentSample, sample == currentSample,
              UserDefaults.standard.bool(forKey: "useSampleData") == sample,
              environment.calendar.isDate(day, inSameDayAs: environment.now),
              record.domainProfile() == profile, record.movementsToAvoid == movementNote,
              model.canonicalOptions == options, model.movementMode == movementMode, model.avoids == avoids,
              store.loadID == loadID,
              !SafetyGate.evaluate(store.safetyFlags).blocksPerformanceRecommendations,
              AdvisorProviderFactory.availability(sample: currentSample) == .ready else { return false }
        do {
            try store.validateSource(source, profile: record, sample: currentSample, environment: environment)
            return true
        } catch { return false }
    }
}

extension AlternativesViewModel {
    func stopOrdering(restoreTemplates: Bool = true) {
        orderingGeneration = UUID()
        orderingTask?.cancel(); orderingTask = nil
        orderingTimeout?.cancel(); orderingTimeout = nil
        isRanking = false
        if restoreTemplates {
            if let canonicalOptions { result = .options(canonicalOptions) }
            rankingMessage = "Template order. The option details are always deterministic."
        }
    }

    func freezeOrdering() {
        guard !orderingFrozen || isRanking else { return }
        let wasRanking = isRanking
        stopOrdering(restoreTemplates: false)
        orderingFrozen = true
        if wasRanking { rankingMessage = "Keeping the current order while you review these options." }
    }

    func tryOnDeviceOrder(source: PlanItem, profile: ProfileRecord, snapshot: PhaseOneContextSnapshot?,
                          store: PlanStore, environment: AppEnvironment, sample: Bool) {
        guard !isRanking, !orderingFrozen, let options = canonicalOptions,
              environment.advisor.isEnabled(profileID: profile.id, sample: sample),
              let provider = AdvisorProviderFactory.optionalProvider(sample: sample) else { return }
        stopOrdering()
        isRanking = true
        rankingMessage = "Trying on-device ordering. You can choose, defer, or rest without waiting."
        let captured = AlternativeAdvisorRequest(generation: orderingGeneration,
            preferenceRevision: environment.advisor.revision, day: environment.now,
            profile: profile.domainProfile(), movementNote: profile.movementsToAvoid, sample: sample,
            source: source, options: options, movementMode: movementMode, avoids: avoids, loadID: store.loadID)
        // An independent timeout invalidates delivery even if the SDK ignores cancellation.
        orderingTimeout = Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard !Task.isCancelled, let self, captured.generation == self.orderingGeneration else { return }
            self.stopOrdering()
            self.rankingMessage = "Ordering took too long. The usual template options are ready."
            environment.advisor.record(.timedOut, revision: captured.preferenceRevision)
        }
        orderingTask = Task { [weak self] in
            guard let self else { return }
            guard captured.isCurrent(model: self, profile: profile, sample: sample, store: store, environment: environment),
                  await store.refreshSafety(profile: profile, sample: sample, environment: environment),
                  !Task.isCancelled,
                  captured.isCurrent(model: self, profile: profile, sample: sample, store: store, environment: environment) else {
                self.finishDiscarded(captured, store: store, environment: environment)
                return
            }
            let decision = await AdvisorCoordinator().advise(alternatives: options, outcome: source.outcome,
                context: AdvisorContext(availableMinutes: snapshot?.availability.freeMinutesToday, lowDataMode: profile.lowDataMode),
                safetyFlags: store.safetyFlags, optionalProvider: provider)
            guard !Task.isCancelled,
                  await store.refreshSafety(profile: profile, sample: sample, environment: environment),
                  !Task.isCancelled,
                  captured.isCurrent(model: self, profile: profile, sample: sample, store: store, environment: environment) else {
                self.finishDiscarded(captured, store: store, environment: environment)
                return
            }
            self.orderingTimeout?.cancel(); self.orderingTimeout = nil
            self.isRanking = false
            switch decision {
            case .ranked(let selection):
                self.result = .options(selection.alternatives)
                self.rankingMessage = selection.source == .onDevice
                    ? "On-device order. These are the same template options, with unchanged details."
                    : "Using the usual template order. The optional model did not provide a usable order."
                environment.advisor.record(selection.source == .onDevice ? .onDevice : .fallback,
                                           revision: captured.preferenceRevision)
            case .blocked(let message): self.result = .blocked(message)
            case .unavailable:
                self.rankingMessage = "Using the usual template order. No optional ordering was applied."
                environment.advisor.record(.fallback, revision: captured.preferenceRevision)
            }
            self.orderingTask = nil
        }
    }

    private func finishDiscarded(_ request: AlternativeAdvisorRequest, store: PlanStore, environment: AppEnvironment) {
        guard request.generation == orderingGeneration else { return }
        stopOrdering()
        if case .pauseRecommendations(let message) = SafetyGate.evaluate(store.safetyFlags) {
            canonicalOptions = nil
            result = .blocked(message)
        }
        rankingMessage = "Context changed. The optional order was discarded."
        environment.advisor.record(.discarded, revision: request.preferenceRevision)
    }
}
