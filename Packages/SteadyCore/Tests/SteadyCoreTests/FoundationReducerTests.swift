import Foundation
import Testing
@testable import SteadyCore

@Suite("Daily Foundation user actions")
struct FoundationReducerTests {
    @Test("Done is explicit and idempotent for every family")
    func completion() throws {
        for kind in FoundationKind.allCases {
            let original = foundationState()
            let event = foundationEvent(kind, .done)
            let done = try foundationApply(event, to: original)
            #expect(done.items.first { $0.kind == kind }?.status == .done)
            #expect(original.items.allSatisfy { $0.status == .available })
            #expect(done.appliedEventIDs == [event.id])
            #expect(try foundationApply(event, to: done) == done)
            #expect(throws: FoundationError.inactiveItem) {
                try foundationApply(foundationEvent(kind, .done, id: "again"), to: done)
            }
        }
    }

    @Test("Replacing any family changes only its option, never completion")
    func replacement() throws {
        for kind in FoundationKind.allCases {
            let option = try #require(FoundationCatalog.options(for: kind).last)
            let replaced = try foundationApply(foundationEvent(kind, .replace(optionID: option.id)), to: foundationState())
            let item = try #require(replaced.items.first { $0.kind == kind })
            #expect(item.status == .replaced && item.optionID == option.id)
            #expect(replaced.items.filter { $0.kind != kind }.allSatisfy { $0.status == .available })
            #expect(replaced.settings == FoundationSettings())
        }
    }

    @Test("Snoozing every family records only a future local deadline")
    func snooze() throws {
        for kind in FoundationKind.allCases {
            let until = testDate(2026, 10, 16, 10, 30)
            let state = try foundationApply(foundationEvent(kind, .snooze(until: until)), to: foundationState())
            let item = try #require(state.items.first { $0.kind == kind })
            #expect(item.status == .snoozed && item.snoozedUntil == until)
            #expect(item.optionID == foundationState().items.first { $0.kind == kind }?.optionID)
        }
    }

    @Test("Disable persists the preference and explicit enable restores the kind")
    func disableAndEnable() throws {
        for kind in FoundationKind.allCases {
            let disabled = try foundationApply(foundationEvent(kind, .disable), to: foundationState())
            #expect(disabled.settings.disabledKinds.contains(kind))
            #expect(disabled.items.first { $0.kind == kind }?.status == .disabled)
            #expect(throws: FoundationError.inactiveItem) {
                try foundationApply(foundationEvent(kind, .done, id: "done"), to: disabled)
            }
            let enabled = try foundationApply(foundationEvent(kind, .enable, id: "enable"), to: disabled)
            #expect(!enabled.settings.disabledKinds.contains(kind))
            #expect(enabled.items.first { $0.kind == kind }?.status == .available)
        }
    }

    @Test("Unknown, cross-family, and unchanged replacement IDs are rejected")
    func rejectedReplacements() throws {
        let state = foundationState()
        let original = try #require(state.items.first { $0.kind == .mobility }?.optionID)
        for id in ["invented", "hydration-meal"] {
            #expect(throws: FoundationError.unknownOption) {
                try foundationApply(foundationEvent(.mobility, .replace(optionID: id)), to: state)
            }
        }
        #expect(throws: FoundationError.unchangedOption) {
            try foundationApply(foundationEvent(.mobility, .replace(optionID: original)), to: state)
        }
    }

    @Test("A replacement excluded by an updated movement control is not accepted")
    func movementRestrictionAtAction() throws {
        let settings = FoundationSettings(movementMode: .wheelchair, movementsToAvoid: [.lowerBody])
        #expect(throws: FoundationError.unknownOption) {
            try foundationApply(
                foundationEvent(.mobility, .replace(optionID: "mobility-standing-ankles")),
                to: foundationState(settings: settings)
            )
        }
    }

    @Test("Past, same-time, nonfinite, cross-midnight, and overlong snoozes are rejected")
    func invalidSnoozes() {
        let invalid = [
            testDate(2026, 10, 16, 9), testDate(2026, 10, 16, 10),
            Date(timeIntervalSince1970: .nan), testDate(2026, 10, 17, 0), testDate(2026, 10, 16, 23)
        ]
        for until in invalid {
            #expect(throws: FoundationError.invalidSnooze) {
                try foundationApply(foundationEvent(.reset, .snooze(until: until)), to: foundationState())
            }
        }
    }

    @Test("Actions from yesterday or tomorrow cannot mutate today's state")
    func staleEvents() {
        for day in [testDate(2026, 10, 15), testDate(2026, 10, 17)] {
            #expect(throws: FoundationError.staleDay) {
                try foundationApply(foundationEvent(.reset, .done, day: day), to: foundationState())
            }
        }
    }

    @Test("A local midnight rollover rejects even a previously applied event")
    func staleDeliveryAfterRollover() throws {
        let event = foundationEvent(.reset, .done)
        let state = try foundationApply(event, to: foundationState())
        #expect(throws: FoundationError.staleDay) {
            try foundationApply(event, to: state, now: testDate(2026, 10, 17))
        }
    }

    @Test("Safety is rechecked for every performance action, not just card generation")
    func safetyAtAction() throws {
        let state = foundationState()
        let option = try #require(FoundationCatalog.options(for: .reset).last)
        for action in [FoundationAction.done, .replace(optionID: option.id), .snooze(until: testDate(2026, 10, 16, 11))] {
            #expect(throws: FoundationError.safetyBlocked) {
                try foundationApply(foundationEvent(.reset, action), to: state, safetyFlags: [.userReported(.pain)])
            }
        }
        let disabled = try foundationApply(foundationEvent(.reset, .disable), to: state, safetyFlags: [.userReported(.pain)])
        #expect(disabled.settings.disabledKinds.contains(.reset))
        let enabled = try foundationApply(foundationEvent(.reset, .enable, id: "enable"), to: disabled, safetyFlags: [.userReported(.pain)])
        #expect(FoundationCatalog.options(for: .reset, settings: enabled.settings, safetyFlags: [.userReported(.pain)]).isEmpty)
    }

    @Test("Empty event IDs and malformed item collections are rejected")
    func malformedInputs() {
        #expect(throws: FoundationError.emptyEventID) {
            try foundationApply(foundationEvent(.reset, .done, id: "  \n"), to: foundationState())
        }
        let malformed = FoundationDayState(day: testDate(), items: Array(repeating: FoundationItemState(kind: .reset), count: 6))
        #expect(throws: FoundationError.invalidState) {
            try foundationApply(foundationEvent(.reset, .done), to: malformed)
        }
        let invalidDay = FoundationDayState(day: Date(timeIntervalSince1970: .nan))
        #expect(throws: FoundationError.staleDay) {
            try foundationApply(foundationEvent(.reset, .done), to: invalidDay)
        }
    }
}
