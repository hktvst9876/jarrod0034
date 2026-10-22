import Foundation
import Testing
@testable import SteadyCore

struct WatchSnapshotTests {
    @Test func builderCreatesSmallFreshCanonicalProjection() throws {
        let snapshot = watchSnapshot()
        #expect(snapshot.alternatives.map(\.id) == ["watch-a", "watch-b", "watch-c"])
        #expect(snapshot.plan?.id == "watch-plan")
        #expect(snapshot.priority?.title == "Go easier")
        #expect(snapshot.createdAt == watchNow)
        #expect(WatchSnapshotValidator.issue(in: snapshot, clock: watchClock) == nil)
        let text = String(decoding: try WatchWireCodec.encode(snapshot), as: UTF8.self)
        #expect(!text.contains("private sleep"))
        #expect(!text.contains("Private health title"))
        #expect(!text.contains("private-rule"))
        #expect(!text.contains("recovery"))
    }

    @Test func lowDataRedactsFreeTextBeforeEncoding() throws {
        let snapshot = watchSnapshot(lowDataMode: true, plan: watchPlan(title: "Private weight 456 target"))
        #expect(snapshot.priority?.title == "Today's priority")
        #expect(snapshot.plan?.title == "A comfortable walk")
        #expect(snapshot.savedMeals.first?.title == "Saved dish A")
        // Check only the encoded strings. Searching the raw JSON also matched digits
        // inside numeric fields: the encoded `day` (813945600 in Singapore time)
        // contains "456" although no free text leaked.
        let strings = encodedStrings(try JSONSerialization.jsonObject(with: WatchWireCodec.encode(snapshot)))
        for forbidden in ["Private", "calories", "weight", "recovery", "123", "456", "789"] {
            #expect(!strings.contains { $0.contains(forbidden) }, "free text leaked: \(forbidden)")
        }
        #expect(WatchSnapshotValidator.issue(in: snapshot, clock: watchClock) == nil)
    }

    private func encodedStrings(_ value: Any) -> [String] {
        switch value {
        case let string as String: return [string]
        case let array as [Any]: return array.flatMap(encodedStrings)
        case let object as [String: Any]: return object.flatMap { [$0.key] + encodedStrings($0.value) }
        default: return []
        }
    }

    @Test func lowDataRejectsLeakedPriorityReasonAndMealTitle() {
        let snapshot = watchSnapshot(lowDataMode: true)
        let reasonLeak = watchReplacing(snapshot, priority: WatchPriorityCard(title: "Today's priority", reason: "Sleep 3h"))
        #expect(WatchSnapshotValidator.issue(in: reasonLeak, clock: watchClock) == .invalidSnapshot)
        let mealLeak = watchReplacing(snapshot, savedMeals: [WatchSavedMealCard(id: "saved-meal", title: "400 calories")])
        #expect(WatchSnapshotValidator.issue(in: mealLeak, clock: watchClock) == .invalidSnapshot)
    }

    @Test func safetyRemovesPerformanceCardsAndManualMovementActions() {
        let snapshot = watchSnapshot(safetyBlocked: true)
        #expect(snapshot.plan == nil)
        #expect(snapshot.alternatives.isEmpty)
        #expect(snapshot.foundation == nil)
        #expect(snapshot.movementKinds.isEmpty)
        #expect(snapshot.priority?.title == "Look after yourself")
        #expect(snapshot.savedMeals.count == 1)
        #expect(WatchSnapshotValidator.issue(in: snapshot, clock: watchClock) == nil)
    }

    @Test func safetyBitAloneCannotHidePerformancePayload() {
        let bad = watchReplacing(watchSnapshot(), safetyBlocked: true)
        #expect(WatchSnapshotValidator.issue(in: bad, clock: watchClock) == .invalidSnapshot)
    }

    @Test func completedAndDeferredPlansOfferNoQuickAlternatives() {
        for status in [PlanStatus.completed, .intentionallyRested, .deferred] {
            #expect(watchSnapshot(plan: watchPlan(status: status)).alternatives.isEmpty)
        }
    }

    @Test func snapshotExpiryStopsAtSingaporeMidnight() {
        let late = testDate(2026, 10, 18, 23, 58)
        let snapshot = watchSnapshot(clock: FixedClock(now: late))
        #expect(snapshot.expiresAt == testDate(2026, 10, 19))
        #expect(WatchSnapshotValidator.issue(in: snapshot, clock: FixedClock(now: testDate(2026, 10, 19))) == .staleDay)
    }

    @Test func expiredSnapshotCannotBeAccepted() {
        let snapshot = watchSnapshot()
        #expect(WatchSnapshotValidator.issue(in: snapshot, clock: FixedClock(now: snapshot.expiresAt)) == .expiredSnapshot)
    }

    @Test func futureOrInvalidLifetimeRejected() {
        let original = watchSnapshot()
        #expect(WatchSnapshotValidator.issue(in: watchReplacing(original, createdAt: watchNow.addingTimeInterval(1)), clock: watchClock) == .futureTimestamp)
        #expect(WatchSnapshotValidator.issue(in: watchReplacing(original, expiresAt: watchNow.addingTimeInterval(14_401)), clock: watchClock) == .invalidSnapshot)
        #expect(WatchSnapshotValidator.issue(in: watchReplacing(original, expiresAt: watchNow), clock: watchClock) == .invalidSnapshot)
    }

    @Test func onlyTwoOrThreeDistinctAlternativesAccepted() {
        let snapshot = watchSnapshot()
        for options in [Array(snapshot.alternatives.prefix(1)), snapshot.alternatives + [snapshot.alternatives[0]], [snapshot.alternatives[0], snapshot.alternatives[0]]] {
            #expect(WatchSnapshotValidator.issue(in: watchReplacing(snapshot, alternatives: options), clock: watchClock) == .invalidSnapshot)
        }
        #expect(WatchSnapshotValidator.issue(in: watchReplacing(snapshot, alternatives: []), clock: watchClock) == nil)
    }

    @Test func monotonicRevisionPreventsRollbackAcrossScopeChanges() {
        let current = watchSnapshot(revision: 9)
        let older = watchSnapshot(id: "older", revision: 8, profileID: UUID(), sample: true)
        #expect(WatchSnapshotValidator.accept(older, replacing: current, clock: watchClock) == .rejected(.staleSnapshot))
        let next = watchSnapshot(id: "next", revision: 10, profileID: UUID(), sample: true)
        #expect(WatchSnapshotValidator.accept(next, replacing: current, clock: watchClock) == .accepted)
    }

    @Test func duplicateSnapshotIsInertButConflictingIDRejected() {
        let snapshot = watchSnapshot()
        #expect(WatchSnapshotValidator.accept(snapshot, replacing: snapshot, clock: watchClock) == .unchanged)
        let conflict = watchReplacing(snapshot, revision: 2)
        #expect(WatchSnapshotValidator.accept(conflict, replacing: snapshot, clock: watchClock) == .rejected(.conflictingReplay))
    }

    @Test func persistentWatermarkPreventsRollbackAfterVisibleSnapshotRemoved() {
        #expect(WatchSnapshotValidator.accept(watchSnapshot(revision: 7), replacing: nil, minimumRevision: 9, clock: watchClock) == .rejected(.staleSnapshot))
        #expect(WatchSnapshotValidator.accept(watchSnapshot(revision: 10), replacing: nil, minimumRevision: 9, clock: watchClock) == .accepted)
        let older = watchSnapshot(revision: 7)
        #expect(WatchSnapshotValidator.accept(older, replacing: older, minimumRevision: 9, clock: watchClock) == .rejected(.staleSnapshot))
    }

    @Test func invalidDayVersionAndIdentifiersRejected() {
        let snapshot = watchSnapshot()
        #expect(WatchSnapshotValidator.issue(in: watchReplacing(snapshot, schemaVersion: 99), clock: watchClock) == .unsupportedVersion)
        #expect(WatchSnapshotValidator.issue(in: watchReplacing(snapshot, id: "\n"), clock: watchClock) == .invalidIdentifier)
        #expect(WatchSnapshotValidator.issue(in: watchReplacing(snapshot, revision: 0), clock: watchClock) == .invalidIdentifier)
        #expect(WatchSnapshotValidator.issue(in: watchReplacing(snapshot, day: watchNow), clock: watchClock) == .staleDay)
    }
}
