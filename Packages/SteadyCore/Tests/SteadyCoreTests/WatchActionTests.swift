import Foundation
import Testing
@testable import SteadyCore

struct WatchActionTests {
    @Test func allowlistedAlternativeCanBeApplied() {
        #expect(watchEvaluate(watchAction()) == .apply)
    }

    @Test func unknownAlternativeRejectedRatherThanSubstituted() {
        #expect(watchEvaluate(watchAction(kind: .chooseAlternative(optionID: "foreign"))) == .reject(.unknownOption))
    }

    @Test func movementIsFixedManualRecordNotArbitraryPrescription() {
        for kind in WatchMovementKind.allCases {
            for minutes in WatchMovementKind.allowedMinutes {
                #expect(watchEvaluate(watchAction(kind: .logMovement(kind: kind, minutes: minutes))) == .apply)
            }
        }
        for minutes in [-1, 0, 4, 6, 180, Int.max] {
            #expect(watchEvaluate(watchAction(kind: .logMovement(kind: .walk, minutes: minutes))) == .reject(.invalidMovement))
        }
    }

    @Test func movementKindMustRemainAllowedInCurrentContext() {
        let snapshot = watchSnapshot()
        let context = WatchCurrentContext(
            profileID: snapshot.profileID, useSampleData: false, day: snapshot.day,
            snapshotID: snapshot.id, snapshotRevision: snapshot.revision,
            lowDataMode: false, safetyBlocked: false, movementKinds: [.mobility]
        )
        #expect(watchEvaluate(watchAction(kind: .logMovement(kind: .walk, minutes: 5)), current: context) == .reject(.invalidMovement))
    }

    @Test func foundationRequiresSameFamilyAndCurrentOption() throws {
        let snapshot = watchSnapshot()
        let foundation = try #require(snapshot.foundation)
        let action = watchAction(kind: .foundationDone(kind: foundation.kind, optionID: foundation.optionID))
        #expect(watchEvaluate(action) == .apply)
        #expect(watchEvaluate(watchAction(kind: .foundationDone(kind: .windDown, optionID: foundation.optionID))) == .reject(.unknownOption))
        #expect(watchEvaluate(watchAction(kind: .foundationDone(kind: foundation.kind, optionID: "changed-option"))) == .reject(.unknownOption))
    }

    @Test func handoffOnlyReferencesAlreadySavedRecord() {
        #expect(watchEvaluate(watchAction(kind: .savedMealHandoff(savedCorrectionID: "saved-meal"))) == .apply)
        #expect(watchEvaluate(watchAction(kind: .savedMealHandoff(savedCorrectionID: "new-meal"))) == .reject(.unknownOption))
    }

    @Test func profileAndSampleMismatchRejected() {
        #expect(watchEvaluate(watchAction(profileID: UUID())) == .reject(.profileMismatch))
        #expect(watchEvaluate(watchAction(sample: true)) == .reject(.sampleMismatch))
    }

    @Test func staleSnapshotIDAndRevisionRejected() {
        let old = watchSnapshot(id: "old", revision: 1)
        let latest = watchSnapshot(id: "latest", revision: 2)
        #expect(watchEvaluate(watchAction(snapshot: old), snapshot: latest) == .reject(.staleSnapshot))
        let wrongRevision = watchSnapshot(id: latest.id, revision: 1)
        #expect(watchEvaluate(watchAction(snapshot: wrongRevision), snapshot: latest) == .reject(.staleSnapshot))
    }

    @Test func previousDayActionDoesNotCompleteTodaysDifferentState() {
        let action = watchAction(day: testDate(2026, 10, 17))
        #expect(watchEvaluate(action) == .reject(.staleDay))
    }

    @Test func actionTimestampMustBeInsideCapturedSnapshotAndNotFuture() {
        #expect(watchEvaluate(watchAction(createdAt: watchNow.addingTimeInterval(-1))) == .reject(.expiredSnapshot))
        #expect(watchEvaluate(watchAction(createdAt: watchNow.addingTimeInterval(1))) == .reject(.futureTimestamp))
        let invalid = watchAction(createdAt: Date(timeIntervalSince1970: .infinity))
        #expect(watchEvaluate(invalid) == .reject(.malformedPayload))
    }

    @Test func expiredOfflineActionIsNotAppliedAtReconnection() {
        let snapshot = watchSnapshot()
        #expect(watchEvaluate(watchAction(), clock: FixedClock(now: snapshot.expiresAt)) == .reject(.expiredSnapshot))
    }

    @Test func newlyChangedLowDataOrSafetyContextInvalidatesOldAction() {
        let snapshot = watchSnapshot()
        let context = WatchCurrentContext(
            profileID: snapshot.profileID, useSampleData: snapshot.useSampleData, day: snapshot.day,
            snapshotID: snapshot.id, snapshotRevision: snapshot.revision, lowDataMode: true,
            safetyBlocked: false, alternativeOptionIDs: ["watch-a"]
        )
        #expect(watchEvaluate(watchAction(), current: context) == .reject(.contextChanged))
        let unsafe = WatchCurrentContext(
            profileID: snapshot.profileID, useSampleData: snapshot.useSampleData, day: snapshot.day,
            snapshotID: snapshot.id, snapshotRevision: snapshot.revision, lowDataMode: false,
            safetyBlocked: true, alternativeOptionIDs: ["watch-a"]
        )
        #expect(watchEvaluate(watchAction(), current: unsafe) == .reject(.contextChanged))
    }

    @Test func safetyBlocksPerformanceButNotInertSavedMealRoute() {
        let snapshot = watchSnapshot(safetyBlocked: true)
        #expect(watchEvaluate(watchAction(snapshot: snapshot), snapshot: snapshot) == .reject(.safetyBlocked))
        #expect(watchEvaluate(watchAction(snapshot: snapshot, kind: .logMovement(kind: .walk, minutes: 5)), snapshot: snapshot) == .reject(.safetyBlocked))
        #expect(watchEvaluate(watchAction(snapshot: snapshot, kind: .savedMealHandoff(savedCorrectionID: "saved-meal")), snapshot: snapshot) == .apply)
    }

    @Test func currentAllowlistMustStillContainSelectedOption() {
        let snapshot = watchSnapshot()
        let noChoices = WatchCurrentContext(
            profileID: snapshot.profileID, useSampleData: false, day: snapshot.day,
            snapshotID: snapshot.id, snapshotRevision: snapshot.revision,
            lowDataMode: false, safetyBlocked: false
        )
        #expect(watchEvaluate(watchAction(), current: noChoices) == .reject(.unknownOption))
    }

    @Test func duplicateActionReturnsStoredReceiptWithoutNewMutationEvenWhenExpired() {
        let action = watchAction()
        let receipt = WatchActionReceipt(action: action, status: .accepted, processedAt: watchNow)
        let tomorrow = FixedClock(now: testDate(2026, 10, 19, 13))
        #expect(watchEvaluate(action, receipts: [receipt], clock: tomorrow) == .replay(receipt))
    }

    @Test func rejectedReceiptAlsoReplaysWithoutReconsideringAction() {
        let action = watchAction()
        let receipt = WatchActionReceipt(action: action, status: .rejected(.staleSnapshot), processedAt: watchNow)
        #expect(watchEvaluate(action, receipts: [receipt]) == .replay(receipt))
    }

    @Test func sameActionIDDifferentPayloadCannotReplacePriorReceipt() {
        let action = watchAction()
        let receipt = WatchActionReceipt(action: action, status: .accepted, processedAt: watchNow)
        let conflict = watchAction(kind: .logMovement(kind: .walk, minutes: 10))
        #expect(watchEvaluate(conflict, receipts: [receipt]) == .reject(.conflictingReplay))
        let retimestamp = watchAction(createdAt: watchNow.addingTimeInterval(1))
        #expect(watchEvaluate(retimestamp, receipts: [receipt]) == .reject(.conflictingReplay))
    }

    @Test func conflictingPersistedReceiptsFailClosed() {
        let action = watchAction()
        let accepted = WatchActionReceipt(action: action, status: .accepted, processedAt: watchNow)
        let rejected = WatchActionReceipt(action: action, status: .rejected(.unavailable), processedAt: watchNow)
        #expect(watchEvaluate(action, receipts: [accepted, rejected]) == .reject(.conflictingReplay))
    }

    @Test func emptyAndControlCharacterActionIDsRejected() {
        for id in ["", "  ", "unsafe\nID", String(repeating: "x", count: 257)] {
            #expect(watchEvaluate(watchAction(id: id)) == .reject(.invalidIdentifier))
        }
    }
}
