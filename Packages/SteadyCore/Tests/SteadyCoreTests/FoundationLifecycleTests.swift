import Foundation
import Testing
@testable import SteadyCore

@Suite("Daily Foundation lifecycle")
struct FoundationLifecycleTests {
    @Test("Same-day refresh preserves done, replacement, snooze, and idempotency history")
    func refresh() throws {
        var state = foundationState()
        state = try foundationApply(foundationEvent(.hydration, .done, id: "done"), to: state)
        state = try foundationApply(foundationEvent(.reset, .replace(optionID: "reset-breathe"), id: "replace"), to: state)
        state = try foundationApply(foundationEvent(.daylight, .snooze(until: testDate(2026, 10, 16, 12)), id: "later"), to: state)
        let refreshed = FoundationReducer.startDay(
            at: testDate(2026, 10, 16, 11), settings: state.settings,
            previous: state, calendar: testCalendar
        )
        #expect(refreshed == state)
    }

    @Test("A new Singapore day resets progress but keeps explicit preferences")
    func newDay() throws {
        let settings = FoundationSettings(disabledKinds: [.daylight], movementMode: .wheelchair, movementsToAvoid: [.lowerBody])
        let old = try foundationApply(foundationEvent(.reset, .done), to: foundationState(settings: settings))
        let next = FoundationReducer.startDay(
            at: testDate(2026, 10, 17, 0, 1), settings: old.settings, previous: old, calendar: testCalendar
        )
        #expect(next.day == testDate(2026, 10, 17))
        #expect(next.settings == settings)
        #expect(next.appliedEventIDs.isEmpty)
        #expect(next.items.first { $0.kind == .reset }?.status == .available)
        #expect(next.items.first { $0.kind == .daylight }?.status == .disabled)
        let mobilityID = try #require(next.items.first { $0.kind == .mobility }?.optionID)
        #expect(mobilityID == "mobility-shoulders")
    }

    @Test("Expired snoozes become available again without being marked done")
    func expiry() throws {
        let until = testDate(2026, 10, 16, 11)
        var state = try foundationApply(foundationEvent(.windDown, .snooze(until: until)), to: foundationState())
        state = FoundationReducer.reconcile(settings: state.settings, state: state, now: until, calendar: testCalendar)
        let item = try #require(state.items.first { $0.kind == .windDown })
        #expect(item.status == .available && item.snoozedUntil == nil)
        #expect(state.appliedEventIDs == ["event"])
    }

    @Test("A replaced snoozed item keeps its selected option when it returns")
    func replacedSnooze() throws {
        var state = try foundationApply(foundationEvent(.reset, .replace(optionID: "reset-breathe")), to: foundationState())
        state = try foundationApply(foundationEvent(.reset, .snooze(until: testDate(2026, 10, 16, 11)), id: "snooze"), to: state)
        let resumed = try foundationApply(foundationEvent(.reset, .resume, id: "resume"), to: state)
        #expect(resumed.items.first { $0.kind == .reset }?.status == .replaced)
        #expect(resumed.items.first { $0.kind == .reset }?.optionID == "reset-breathe")
        #expect(resumed.items.first { $0.kind == .reset }?.snoozedUntil == nil)
        #expect(throws: FoundationError.invalidTransition) {
            try foundationApply(foundationEvent(.reset, .resume, id: "again"), to: resumed)
        }
    }

    @Test("Resuming a stale suggestion is still safety checked")
    func resumeSafety() throws {
        let state = try foundationApply(
            foundationEvent(.mobility, .snooze(until: testDate(2026, 10, 16, 11))), to: foundationState()
        )
        #expect(throws: FoundationError.safetyBlocked) {
            try foundationApply(foundationEvent(.mobility, .resume, id: "resume"), to: state, safetyFlags: [.userReported(.fainting)])
        }
    }

    @Test("Changing mode invalidates an unsuitable selected movement but not completed history")
    func settingsChange() throws {
        var old = foundationState()
        old = try foundationApply(foundationEvent(.movementBreak, .done), to: old)
        let settings = FoundationSettings(movementMode: .wheelchair, movementsToAvoid: [.standing, .lowerBody])
        let updated = FoundationReducer.reconcile(settings: settings, state: old, now: testDate(2026, 10, 16, 11), calendar: testCalendar)
        #expect(updated.items.first { $0.kind == .mobility }?.optionID == "mobility-shoulders")
        #expect(updated.items.first { $0.kind == .movementBreak }?.status == .done)
        #expect(updated.items.first { $0.kind == .movementBreak }?.optionID == "movement-standing")
        #expect(updated.appliedEventIDs == old.appliedEventIDs)
    }

    @Test("Disabled settings can be reconciled and explicitly cleared without restarting the app")
    func settingsDisableAndEnable() {
        let settings = FoundationSettings(disabledKinds: Set(FoundationKind.allCases))
        let disabled = FoundationReducer.reconcile(settings: settings, state: foundationState(), now: testDate(2026, 10, 16, 11), calendar: testCalendar)
        #expect(disabled.items.allSatisfy { $0.status == .disabled && $0.optionID == nil })
        let enabled = FoundationReducer.reconcile(settings: FoundationSettings(), state: disabled, now: testDate(2026, 10, 16, 11), calendar: testCalendar)
        #expect(enabled.items.allSatisfy { $0.status == .available && $0.optionID != nil })
    }

    @Test("Daily state, settings, options and every action round-trip locally")
    func persistence() throws {
        let settings = FoundationSettings(disabledKinds: [.daylight], movementMode: .seated, movementsToAvoid: [.walking])
        let state = try foundationApply(foundationEvent(.hydration, .done), to: foundationState(settings: settings))
        #expect(try JSONDecoder().decode(FoundationDayState.self, from: JSONEncoder().encode(state)) == state)
        let actions: [FoundationAction] = [.done, .replace(optionID: "reset-breathe"), .snooze(until: testDate(2026, 10, 16, 11)), .disable, .enable, .resume]
        for action in actions {
            let event = foundationEvent(.reset, action)
            #expect(try JSONDecoder().decode(FoundationEvent.self, from: JSONEncoder().encode(event)) == event)
        }
        for option in FoundationCatalog.options(for: .reset) {
            #expect(try JSONDecoder().decode(FoundationOption.self, from: JSONEncoder().encode(option)) == option)
        }
    }

    @Test("Nonfinite initial time yields no actionable items rather than consulting system time")
    func invalidInitialTime() {
        let state = FoundationReducer.startDay(at: Date(timeIntervalSince1970: .nan), settings: FoundationSettings())
        #expect(state.items.isEmpty)
        #expect(state.appliedEventIDs.isEmpty)
    }
}
