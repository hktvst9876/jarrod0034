import Foundation
import Testing
@testable import SteadyCore

struct WeeklyPrivacyTests {
    @Test func freshResetNeedsExplicitCurrentRevision() {
        #expect(LocalResetAuthorization.evaluate(expectedRevision: 0, currentRevision: 0,
            isBlocked: false, hasPendingDeletion: false) == .begin)
        #expect(LocalResetAuthorization.evaluate(expectedRevision: 4, currentRevision: 4,
            isBlocked: false, hasPendingDeletion: false) == .begin)
        #expect(LocalResetAuthorization.evaluate(expectedRevision: 3, currentRevision: 4,
            isBlocked: false, hasPendingDeletion: false) == .refuse)
    }

    @Test func recoveryNeedsReadablePendingConfirmation() {
        #expect(LocalResetAuthorization.evaluate(expectedRevision: nil, currentRevision: 4,
            isBlocked: true, hasPendingDeletion: true) == .resume)
        #expect(LocalResetAuthorization.evaluate(expectedRevision: nil, currentRevision: 4,
            isBlocked: true, hasPendingDeletion: false) == .refuse)
        #expect(LocalResetAuthorization.evaluate(expectedRevision: 4, currentRevision: 4,
            isBlocked: true, hasPendingDeletion: false) == .refuse)
    }

    @Test func delayedRecoveryCannotEraseNewGenerationAfterResetFinished() {
        #expect(LocalResetAuthorization.evaluate(expectedRevision: nil, currentRevision: 4,
            isBlocked: false, hasPendingDeletion: false) == .refuse)
        #expect(LocalResetAuthorization.evaluate(expectedRevision: 0, currentRevision: 4,
            isBlocked: false, hasPendingDeletion: false) == .refuse)
        #expect(LocalResetAuthorization.evaluate(expectedRevision: 4, currentRevision: 4,
            isBlocked: false, hasPendingDeletion: true) == .refuse)
    }

    @Test func resetAuthorizationRejectsInvalidRevisionsAndOverlappingStart() {
        #expect(LocalResetAuthorization.evaluate(expectedRevision: -1, currentRevision: 0,
            isBlocked: false, hasPendingDeletion: false) == .refuse)
        #expect(LocalResetAuthorization.evaluate(expectedRevision: nil, currentRevision: -1,
            isBlocked: true, hasPendingDeletion: true) == .refuse)
        #expect(LocalResetAuthorization.evaluate(expectedRevision: 4, currentRevision: 4,
            isBlocked: true, hasPendingDeletion: true) == .refuse)
    }

    @Test func resetKeepsNotificationsQuietUntilNextSingaporeMidnight() {
        let erased = testDate(2026, 10, 18, 12)
        #expect(WeeklyResetNudgePolicy.shouldStayQuiet(erasedAt: erased, now: testDate(2026, 10, 18, 23, 59)))
        #expect(!WeeklyResetNudgePolicy.shouldStayQuiet(erasedAt: erased, now: testDate(2026, 10, 19)))
        #expect(!WeeklyResetNudgePolicy.shouldStayQuiet(erasedAt: erased, now: testDate(2026, 10, 20)))
    }

    @Test func resetNudgePolicyIsConservativeForRollbackOrInvalidClock() {
        #expect(WeeklyResetNudgePolicy.shouldStayQuiet(erasedAt: weeklyNow, now: weeklyNow.addingTimeInterval(-86_400)))
        #expect(WeeklyResetNudgePolicy.shouldStayQuiet(erasedAt: Date(timeIntervalSinceReferenceDate: .nan), now: weeklyNow))
        #expect(WeeklyResetNudgePolicy.shouldStayQuiet(erasedAt: weeklyNow, now: Date(timeIntervalSinceReferenceDate: .infinity)))
    }

    @Test func normalExportKeepsUserRecordsUnchanged() {
        let record = ["id": "row", "notes": "my note", "payload": "saved value"]
        #expect(WeeklyExportPolicy.project(record, lowDataMode: false) == record)
        #expect(record["notes"] == "my note")
    }

    @Test func lowDataProjectionIsMetadataOnlyAndDropsUnknownBlobAndSensitiveKeys() {
        let record = ["id": "row", "profileID": "profile", "recordKind": "savedDish", "at": "date",
                      "payload": "raw private data", "name": "123 calories", "weight": "70",
                      "recovery": "ready", "nested": "private", "futureUnknownField": "secret"]
        let projected = WeeklyExportPolicy.project(record, lowDataMode: true)
        #expect(projected == ["id": "row", "profileID": "profile", "recordKind": "savedDish", "at": "date"])
        #expect(record.count == 10)
    }

    @Test func lowDataNeverTraversesOrLeaksNestedPayload() throws {
        let record: [String: Any] = ["id": "row", "payload": ["calories": 123, "nested": ["weight": 70]],
                                     "notes": "Recovery private text"]
        let projected = WeeklyExportPolicy.project(record, lowDataMode: true)
        let data = try JSONSerialization.data(withJSONObject: projected, options: [.sortedKeys])
        #expect(String(decoding: data, as: UTF8.self) == "{\"id\":\"row\"}")
        #expect(record["payload"] != nil)
    }

    @Test func lowDataWhitelistKeepsOnlySpecifiedMetadataKeys() {
        let keys = ["id", "key", "profileID", "sampleData", "day", "weekStart", "at", "updatedAt",
                    "createdAt", "confirmedAt", "processedAt", "consumedAt", "recordKind"]
        let input = Dictionary(uniqueKeysWithValues: keys.map { ($0, "metadata") })
        #expect(WeeklyExportPolicy.project(input, lowDataMode: true) == input)
        #expect(WeeklyExportPolicy.project(["reviewData": "private"], lowDataMode: true).isEmpty)
    }

    @Test func eraseControlRoundTripsWithoutPersonalPayloadAndAllowsClockSkew() throws {
        let control = CompanionEraseControl(revision: 5, createdAt: weeklyNow.addingTimeInterval(86_400))
        let encoded = try control.encode()
        #expect(try CompanionEraseControl.decode(encoded) == control)
        #expect(encoded.count <= CompanionEraseControl.maximumBytes)
        #expect(!String(decoding: encoded, as: UTF8.self).contains("profile"))
    }

    @Test func eraseControlRejectsNegativeRevisionVersionMalformedAndOversizedData() {
        #expect(throws: WatchRejectionReason.malformedPayload) { try CompanionEraseControl(revision: -1, createdAt: weeklyNow).encode() }
        #expect(throws: WatchRejectionReason.unsupportedVersion) { try CompanionEraseControl(schemaVersion: 2, revision: 1, createdAt: weeklyNow).encode() }
        #expect(throws: WatchRejectionReason.malformedPayload) { try CompanionEraseControl(revision: 1, createdAt: Date(timeIntervalSinceReferenceDate: .nan)).encode() }
        #expect(throws: WatchRejectionReason.oversizedPayload) { try CompanionEraseControl.decode(Data(repeating: 32, count: 1_025)) }
        #expect(throws: WatchRejectionReason.malformedPayload) { try CompanionEraseControl.decode(Data("{}".utf8)) }
        #expect(throws: WatchRejectionReason.malformedPayload) {
            try CompanionEraseControl.decode(Data("{\"schemaVersion\":1,\"revision\":1,\"createdAt\":0,\"payload\":\"secret\"}".utf8))
        }
    }

    @Test func explicitEraseRemovesOldQueueAndReceiptsButPreservesNewGeneration() throws {
        let oldAction = watchAction(id: "old", snapshot: watchSnapshot(revision: 2))
        let newAction = watchAction(id: "new", snapshot: watchSnapshot(revision: 4))
        let received = watchAction(id: "received", snapshot: watchSnapshot(revision: 1))
        let newReceipt = WatchActionReceipt(action: watchAction(id: "new-receipt", snapshot: watchSnapshot(revision: 4)),
                                            status: .accepted, processedAt: watchNow)
        let state = WatchOutboxState(actions: [oldAction, newAction], receipts: [
            WatchActionReceipt(action: received, status: .accepted, processedAt: watchNow), newReceipt
        ])
        let erased = try WatchOutboxReducer.erase(beforeOrAt: 2, in: state)
        #expect(erased.actions == [newAction])
        #expect(erased.receipts == [newReceipt])
        #expect(try WatchOutboxReducer.erase(beforeOrAt: 2, in: erased) == erased)
        #expect(state.actions.count == 2)
    }

    @Test func lateEraseCannotClearNewerSnapshotGeneration() throws {
        let action = watchAction(snapshot: watchSnapshot(revision: 50))
        let state = WatchOutboxState(actions: [action])
        #expect(try WatchOutboxReducer.erase(beforeOrAt: 3, in: state) == state)
        #expect(throws: WatchRejectionReason.malformedPayload) { try WatchOutboxReducer.erase(beforeOrAt: 0, in: state) }
    }

    @Test func eraseRejectsCorruptOutboxRatherThanResettingSilently() {
        let action = watchAction()
        let corrupt = WatchOutboxState(actions: [action, action])
        #expect(throws: WatchRejectionReason.malformedPayload) { try WatchOutboxReducer.erase(beforeOrAt: 10, in: corrupt) }
    }
}
