import Foundation
import Observation
import SteadyCore
import SwiftData

@MainActor
@Observable
final class WatchPhoneCoordinator {
    var message: String?
    var handoff: WatchMealRoute?
    private(set) var isWorking = false
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var samplePrivacyFrameSent = false
    @ObservationIgnored private var lastPublishedData: Data?
    @ObservationIgnored private var lastPublishedSample: Bool?

    func invalidate() { generation = UUID(); handoff = nil }
    func requestRepublish() { lastPublishedData = nil }

    func refresh(profile: ProfileRecord, sample: Bool, today: TodayViewModel, plans: PlanStore,
                 foundations: FoundationStore, environment: AppEnvironment, context: ModelContext,
                 requestIsCurrent: () -> Bool) async {
        let privacyRevision = DataDeletionGate.shared.revision
        guard !DataDeletionGate.shared.isBlocked,
              !Task.isCancelled, !isWorking, requestIsCurrent(), !context.hasChanges, !foundations.isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        let ticket = generation
        let profileValue = profile.domainProfile()
        let day = environment.calendar.startOfDay(for: environment.now)
        let capturedPlan = plans.plan
        let capturedPriority = today.priority
        let service = environment.companion(useSampleData: sample)
        service.start()
        let flags = (try? await environment.health(useSampleData: sample).safetyFlags(on: environment.now, calendar: environment.calendar))
            ?? plans.safetyFlags
        guard !DataDeletionGate.shared.isBlocked, privacyRevision == DataDeletionGate.shared.revision,
              !Task.isCancelled, ticket == generation, requestIsCurrent(), !context.hasChanges, !plans.isWorking, !foundations.isWorking,
              profile.domainProfile() == profileValue, day == environment.calendar.startOfDay(for: environment.now),
              plans.plan == capturedPlan, today.priority == capturedPriority else { return }
        let safety = flags + plans.reportedFlags(profile, environment: environment) + plans.sessionSafetyFlags + foundations.safetyFlags
        do {
            let transaction = ModelContext(context.container)
            transaction.autosaveEnabled = false
            var issued = try transaction.fetch(FetchDescriptor<WatchIssuedSnapshotRecord>()).first
            if let issued, try WatchWireCodec.decodeSnapshot(issued.snapshotData).createdAt > environment.now {
                // Do not issue a misleading fresh frame after the device clock moves backwards.
                throw WatchPhoneError.unavailable
            }
            if sample {
                // A control frame clears prior real-device content; no sample wellness records cross the live link.
                if !samplePrivacyFrameSent {
                    issued = try publishPrivacyFrame(profileID: profile.id, previous: issued,
                        environment: environment, context: transaction)
                }
            }
            if !sample { try replayCommittedReceipts(environment: environment, context: transaction) }
            var state = try WatchPhoneState.read(profile: profile, sample: sample, today: today, planStore: plans,
                flags: safety, environment: environment, context: transaction)
            if !sample {
                samplePrivacyFrameSent = false
                try processInbox(issued: issued, state: &state, profile: profile, sample: sample,
                    today: today, plans: plans, foundations: foundations, flags: safety,
                    environment: environment, context: context, transaction: transaction)
            }
            guard !Task.isCancelled, ticket == generation, requestIsCurrent(), !context.hasChanges else { return }
            // Re-read after applying an action. Generated timestamps never force a new revision by themselves.
            state = try WatchPhoneState.read(profile: profile, sample: sample, today: today, planStore: plans,
                flags: safety, environment: environment, context: transaction)
            issued = try transaction.fetch(FetchDescriptor<WatchIssuedSnapshotRecord>()).first
            let previous = try issued.map { try WatchWireCodec.decodeSnapshot($0.snapshotData) }
            let snapshot: WatchSnapshot
            let clock = FixedClock(now: environment.now)
            if let issued, let previous, issued.bindingDigest == state.bindingDigest,
               WatchSnapshotValidator.issue(in: previous, clock: clock, calendar: environment.calendar) == nil {
                snapshot = previous
            } else {
                let revision = try nextRevision(previous: issued?.revision, now: environment.now)
                snapshot = WatchSnapshotBuilder.make(id: UUID().uuidString, revision: revision,
                    profileID: profile.id, useSampleData: sample, priority: today.priority, plan: state.plan,
                    alternatives: state.alternatives, foundation: state.foundation,
                    savedMeals: state.saved.prefix(3).map { WatchSavedMealCard(id: $0.id.uuidString, title: $0.candidate.dishName) },
                    movementKinds: state.movementKinds, lowDataMode: profile.lowDataMode,
                    safetyBlocked: SafetyGate.evaluate(safety).blocksPerformanceRecommendations,
                    clock: clock, calendar: environment.calendar, lifetime: 900)
                guard WatchSnapshotValidator.issue(in: snapshot, clock: clock, calendar: environment.calendar) == nil else {
                    throw WatchPhoneError.unavailable
                }
                let encoded = try WatchWireCodec.encode(snapshot)
                if let issued {
                    issued.revision = revision; issued.bindingDigest = state.bindingDigest; issued.snapshotData = encoded
                } else {
                    transaction.insert(try WatchIssuedSnapshotRecord(revision: revision, bindingDigest: state.bindingDigest, snapshot: snapshot))
                }
                try transaction.save()
            }
            try loadHandoff(profile: profile, sample: sample, environment: environment, context: transaction)
            let wire = try WatchWireCodec.encode(snapshot)
            guard service.isAvailable else { throw CompanionTransportError.unavailable }
            if wire != lastPublishedData || lastPublishedSample != sample {
                try service.publish(snapshot: wire)
                lastPublishedData = wire; lastPublishedSample = sample
            }
            if sample { message = "Watch sync paused in sample mode. Sample wellness data stays on this phone." }
            else { message = "The latest Watch snapshot is ready. Queued actions are checked again on this phone before saving." }
        } catch WatchPhoneError.dailyLimit {
            message = "Today's Watch inbox is at its local limit. Pending actions remain queued; phone actions still work."
        } catch WatchPhoneError.busy {
            message = "Watch changes are waiting while the phone finishes its current update."
        } catch {
            lastPublishedData = nil
            message = "Watch sync is waiting. Your phone still works on its own; pending actions have not been claimed as saved."
        }
    }

    private func publishPrivacyFrame(profileID: UUID, previous: WatchIssuedSnapshotRecord?,
                                     environment: AppEnvironment, context: ModelContext) throws -> WatchIssuedSnapshotRecord {
        let snapshot = WatchSnapshotBuilder.make(id: UUID().uuidString, revision: try nextRevision(previous: previous?.revision, now: environment.now),
            profileID: profileID, useSampleData: true, priority: nil, plan: nil, alternatives: nil,
            foundation: nil, savedMeals: [], movementKinds: [], lowDataMode: true, safetyBlocked: false,
            clock: FixedClock(now: environment.now), calendar: environment.calendar, lifetime: 900)
        let row: WatchIssuedSnapshotRecord
        if let previous {
            previous.revision = snapshot.revision; previous.bindingDigest = "sample-privacy-control"
            previous.snapshotData = try WatchWireCodec.encode(snapshot); row = previous
        } else {
            row = try WatchIssuedSnapshotRecord(revision: snapshot.revision, bindingDigest: "sample-privacy-control", snapshot: snapshot)
            context.insert(row)
        }
        try context.save()
        let service = environment.companion(useSampleData: false)
        service.start()
        try service.publish(snapshot: WatchWireCodec.encode(snapshot))
        samplePrivacyFrameSent = true
        return row
    }

    private func nextRevision(previous: Int?, now: Date) throws -> Int {
        let previous = max(previous ?? 0, DataDeletionGate.shared.revision)
        let milliseconds = now.timeIntervalSince1970 * 1_000
        guard milliseconds.isFinite, milliseconds >= 1, milliseconds < Double(Int.max - 1),
              previous < Int.max - 1 else { throw WatchPhoneError.unavailable }
        return max(previous + 1, Int(milliseconds))
    }
}

struct WatchMealRoute: Identifiable {
    let id: String
    let title: String
    let observedAt: Date
}
