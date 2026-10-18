import Foundation
import Observation
import SteadyCore

@MainActor
@Observable
final class AlternativesViewModel {
    var barrier: AlternativeBarrier = .anotherOption
    var result: AlternativeResult?
    var proposals: [RescheduleProposal] = []
    var showLater = false
    var confirmation: RescheduleProposal?
    var requestedConfirmation: RescheduleProposal?
    var movementMode: AlternativeMovementMode = .standing
    var avoids: Set<AlternativeMovement> = []
    var confirmedRestrictions = false
    var calendarAvailable = false
    var catalogMessage: String?
    var canonicalOptions: AlternativeSet?
    var rankingMessage = "Template order. The option details are always deterministic."
    var isRanking = false
    var orderingFrozen = false
    @ObservationIgnored var orderingTask: Task<Void, Never>?
    @ObservationIgnored var orderingTimeout: Task<Void, Never>?
    @ObservationIgnored var orderingGeneration = UUID()

    func refresh(source: PlanItem, profile: ProfileRecord, snapshot: PhaseOneContextSnapshot?, store: PlanStore) {
        stopOrdering()
        orderingFrozen = false
        canonicalOptions = nil
        catalogMessage = nil
        guard profile.movementsToAvoid.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || confirmedRestrictions else {
            result = nil
            return
        }
        var catalog = AlternativeCatalog.empty
        if let url = Bundle.main.url(forResource: "plan-alternatives", withExtension: "json") {
            do { catalog = try AlternativeCatalogLoader.decode(Data(contentsOf: url)) }
            catch { catalogMessage = "Using built-in options while the alternative library is unavailable." }
        }
        result = AlternativeEngine(catalog: catalog).alternatives(
            for: source, barrier: barrier,
            context: AlternativeContext(availableMinutes: snapshot?.availability.freeMinutesToday,
                recoveryStatus: snapshot?.recovery.status ?? .normal, movementMode: movementMode,
                movementsToAvoid: avoids, safetyFlags: store.safetyFlags)
        )
        if let result, case .options(let set) = result { canonicalOptions = set }
    }

    func prepareLater(source: PlanItem, profile: ProfileRecord, snapshot: PhaseOneContextSnapshot?, store: PlanStore,
                      environment: AppEnvironment, sample: Bool) async {
        calendarAvailable = await environment.calendar(useSampleData: sample).accessState() == .fullAccess
        requestedConfirmation = nil
        proposals = await RescheduleAvailabilityLoader.proposals(for: source, profile: profile,
            snapshot: snapshot, environment: environment, sample: sample,
            existingEventIdentifier: store.record?.eventIdentifier, safetyFlags: store.safetyFlags)
        showLater = true
    }
}
