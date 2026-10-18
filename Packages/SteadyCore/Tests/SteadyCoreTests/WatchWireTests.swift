import Foundation
import Testing
@testable import SteadyCore

struct WatchWireTests {
    @Test func allTypedPayloadsRoundTripWithinBounds() throws {
        let snapshot = watchSnapshot()
        let action = watchAction()
        let receipt = WatchActionReceipt(action: action, status: .accepted, processedAt: watchNow)
        #expect(try WatchWireCodec.decodeSnapshot(WatchWireCodec.encode(snapshot)) == snapshot)
        #expect(try WatchWireCodec.decodeAction(WatchWireCodec.encode(action)) == action)
        #expect(try WatchWireCodec.decodeReceipt(WatchWireCodec.encode(receipt)) == receipt)
        #expect(try WatchWireCodec.encode(snapshot).count < WatchWireCodec.snapshotMaximumBytes)
    }

    @Test func wireSchemaContainsNoAuthorityForCalendarFoodSaveOrHealthWrite() throws {
        let actions: [WatchActionKind] = [
            .chooseAlternative(optionID: "watch-a"), .logMovement(kind: .mobility, minutes: 5),
            .foundationDone(kind: .hydration, optionID: "water"),
            .savedMealHandoff(savedCorrectionID: "saved-meal")
        ]
        for kind in actions {
            let text = String(decoding: try WatchWireCodec.encode(watchAction(kind: kind)), as: UTF8.self)
            for forbidden in ["calendar", "ingredient", "nutrition", "price", "HealthKit", "rawHealth", "freeText"] {
                #expect(!text.contains(forbidden))
            }
        }
    }

    @Test func emptyMalformedAndOversizedInputRejectedBeforeDecoding() {
        for data in [Data(), Data("not-json".utf8)] {
            #expect(throws: WatchRejectionReason.malformedPayload) { try WatchWireCodec.decodeAction(data) }
        }
        #expect(throws: WatchRejectionReason.oversizedPayload) {
            try WatchWireCodec.decodeSnapshot(Data(repeating: 32, count: WatchWireCodec.snapshotMaximumBytes + 1))
        }
        #expect(throws: WatchRejectionReason.oversizedPayload) {
            try WatchWireCodec.decodeAction(Data(repeating: 32, count: WatchWireCodec.actionMaximumBytes + 1))
        }
        #expect(throws: WatchRejectionReason.oversizedPayload) {
            try WatchWireCodec.decodeReceipt(Data(repeating: 32, count: WatchWireCodec.receiptMaximumBytes + 1))
        }
    }

    @Test func unsupportedSchemaRejectedOnEncodingAndDecoding() throws {
        let unsupported = watchReplacing(watchSnapshot(), schemaVersion: 99)
        #expect(throws: WatchRejectionReason.unsupportedVersion) { try WatchWireCodec.encode(unsupported) }
        let data = try JSONEncoder().encode(unsupported)
        #expect(throws: WatchRejectionReason.unsupportedVersion) { try WatchWireCodec.decodeSnapshot(data) }
    }

    @Test func oversizedTypedActionCannotReachTransport() {
        let action = watchAction(id: String(repeating: "a", count: 9_000))
        #expect(throws: WatchRejectionReason.oversizedPayload) { try WatchWireCodec.encode(action) }
    }

    @Test func unknownActionCaseCannotBeDecoded() throws {
        let data = try WatchWireCodec.encode(watchAction())
        let text = String(decoding: data, as: UTF8.self).replacingOccurrences(of: "chooseAlternative", with: "writeCalendar")
        #expect(throws: WatchRejectionReason.malformedPayload) { try WatchWireCodec.decodeAction(Data(text.utf8)) }
    }
}
