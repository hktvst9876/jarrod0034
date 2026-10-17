import Foundation
import Testing
@testable import SteadyCore

@Suite("Confirmed rescheduling proposals")
struct ReschedulePlannerTests {
    @Test("An available gap becomes a concrete slot of the original duration")
    func concreteDuration() throws {
        let result = ReschedulePlanner.proposals(
            for: testPlan(minutes: 45), slots: [slot(9, 12)], notBefore: testDate(2026, 10, 16, 10)
        )
        let proposal = try #require(result.first)
        #expect(proposal.start == testDate(2026, 10, 16, 10))
        #expect(proposal.end == testDate(2026, 10, 16, 10, 45))
        #expect(proposal.durationMinutes == 45)
        #expect(proposal.planID == "planned")
    }

    @Test("Elapsed and too-short gaps are never proposed")
    func unavailableGaps() {
        let slots = [slot(7, 8), FreeSlot(
            start: testDate(2026, 10, 16, 10), end: testDate(2026, 10, 16, 10, 20),
            confidence: .calendarDerived
        )]
        #expect(ReschedulePlanner.proposals(
            for: testPlan(minutes: 45), slots: slots, notBefore: testDate(2026, 10, 16, 9)
        ).isEmpty)
    }

    @Test("Rounding up never makes a plan overflow its available gap")
    func roundedWindowAndZeroLimit() {
        let start = testDate(2026, 10, 16, 10)
        let narrow = FreeSlot(start: start, end: start.addingTimeInterval(45 * 60 + 30), confidence: .calendarDerived)
        #expect(ReschedulePlanner.proposals(
            for: testPlan(), slots: [narrow], notBefore: start.addingTimeInterval(59)
        ).isEmpty)
        #expect(ReschedulePlanner.proposals(for: testPlan(), slots: [slot(9, 12)], notBefore: testDate(), limit: 0).isEmpty)
    }

    @Test("Unknown windows cannot be offered as available times")
    func unknownConfidence() {
        let unknown = FreeSlot(start: testDate(2026, 10, 16, 9), end: testDate(2026, 10, 16, 12), confidence: .unknown)
        #expect(ReschedulePlanner.proposals(for: testPlan(), slots: [unknown], notBefore: testDate()).isEmpty)
    }

    @Test("Safety suppresses every reschedule proposal")
    func safetyOverride() {
        #expect(ReschedulePlanner.proposals(
            for: testPlan(), slots: [slot(9, 12)], notBefore: testDate(),
            safetyFlags: [.userReported(.pain)]
        ).isEmpty)
    }

    @Test("Duplicate windows are deduplicated and at most three proposals appear")
    func uniqueAndLimited() {
        let values = [slot(9, 10), slot(9, 10), slot(11, 12), slot(13, 14), slot(15, 16)]
        let result = ReschedulePlanner.proposals(for: testPlan(), slots: values, notBefore: testDate(), limit: 10)
        #expect(result.count == 3)
        #expect(Set(result.map(\.id)).count == 3)
    }

    @Test("A later retry derives the same proposal identity from the same window")
    func stableIdentity() {
        let first = ReschedulePlanner.proposals(for: testPlan(), slots: [slot(9, 12)], notBefore: testDate())
        let retry = ReschedulePlanner.proposals(for: testPlan(), slots: [slot(9, 12)], notBefore: testDate())
        #expect(first == retry)
    }

    @Test("A fresh calendar conflict invalidates an earlier proposal")
    func changedCalendar() {
        let value = proposal(10, 11)
        #expect(ReschedulePlanner.validate(value, now: testDate(), busyIntervals: []) == .valid)
        let conflict = BusyInterval(start: testDate(2026, 10, 16, 10, 30), end: testDate(2026, 10, 16, 12))
        #expect(ReschedulePlanner.validate(value, now: testDate(), busyIntervals: [conflict]) == .calendarConflict)
    }

    @Test("Travel padding blocks adjacent activity until the full buffer has elapsed")
    func travelBuffer() {
        let busy = BusyInterval(start: testDate(2026, 10, 16, 8), end: testDate(2026, 10, 16, 9, 50))
        #expect(ReschedulePlanner.validate(proposal(10, 11), now: testDate(), busyIntervals: [busy]) == .calendarConflict)
        let paddedEnd = RescheduleProposal(id: "later", planID: "p", title: "Walk", start: testDate(2026, 10, 16, 10, 5), end: testDate(2026, 10, 16, 10, 35))
        #expect(ReschedulePlanner.validate(paddedEnd, now: testDate(), busyIntervals: [busy]) == .valid)
    }

    @Test("Invalid and elapsed proposals never authorize a write")
    func invalidTimes() {
        #expect(ReschedulePlanner.validate(proposal(11, 10), now: testDate(), busyIntervals: []) == .invalidTime)
        #expect(ReschedulePlanner.validate(proposal(8, 9), now: testDate(2026, 10, 16, 10), busyIntervals: []) == .inThePast)
        let nan = RescheduleProposal(id: "n", planID: "p", title: "Walk", start: Date(timeIntervalSinceReferenceDate: .nan), end: testDate())
        #expect(nan.durationMinutes == 0)
        #expect(ReschedulePlanner.validate(nan, now: testDate(), busyIntervals: []) == .invalidTime)
    }

    @Test("A newly reported symptom overrides an otherwise valid confirmation")
    func newSafetyFlag() {
        #expect(ReschedulePlanner.validate(
            proposal(10, 11), now: testDate(), busyIntervals: [], safetyFlags: [.userReported(.chestSymptoms)]
        ) == .safetyBlocked)
    }

    @Test("Completed and intentionally rested plans cannot be rescheduled")
    func terminalPlans() {
        for status in [PlanStatus.completed, .intentionallyRested] {
            let plan = PlanItem(id: "done", day: testDate(), type: .walk, title: "Walk", outcome: testPlan().outcome,
                                minutes: 30, slot: nil, status: status, origin: .user)
            #expect(ReschedulePlanner.proposals(for: plan, slots: [slot(9, 12)], notBefore: testDate()).isEmpty)
        }
    }

    @Test("An inert proposal can be saved and recovered without gaining authority")
    func codableProposal() throws {
        let original = proposal(10, 11)
        let data = try JSONEncoder().encode(original)
        #expect(try JSONDecoder().decode(RescheduleProposal.self, from: data) == original)
    }

    private func slot(_ start: Int, _ end: Int) -> FreeSlot {
        FreeSlot(start: testDate(2026, 10, 16, start), end: testDate(2026, 10, 16, end), confidence: .calendarDerived)
    }

    private func proposal(_ start: Int, _ end: Int) -> RescheduleProposal {
        RescheduleProposal(id: "later", planID: "p", title: "Walk", start: testDate(2026, 10, 16, start), end: testDate(2026, 10, 16, end))
    }
}
