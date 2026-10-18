import Foundation
import Testing
@testable import SteadyCore

@Suite("Nudge daily reservations")
struct NudgeBudgetTests {
    @Test("Caller budgets cannot raise the hard daily maximum above three")
    func hardCap() {
        let candidates = FoundationKind.allCases.enumerated().map {
            nudgeCandidate($0.element.rawValue, kind: $0.element, hour: 9 + $0.offset)
        }
        let result = NudgePlanner.plan(candidates: candidates, context: nudgeContext(budget: 99))
        #expect(result.notifications.count == 3)
        #expect(result.silentCards.count == 3)
        #expect(result.silentCards.allSatisfy { $0.silentReason == .budgetReached })
    }

    @Test("Reservations survive replanning and consume capacity even after cancellation or failure")
    func persistentBudget() {
        let reserved = [NudgeReservation(id: "already", kind: .reset, day: testDate())]
        let candidates = [nudgeCandidate("a"), nudgeCandidate("b", kind: .daylight), nudgeCandidate("c", kind: .hydration)]
        let first = NudgePlanner.plan(candidates: candidates, context: nudgeContext(reservations: reserved))
        #expect(first.notifications.map(\.id) == ["a", "b"])
        let ledger = reserved + first.notifications.map {
            NudgeReservation(id: $0.id, kind: $0.kind, day: testDate(), fireAt: $0.fireAt)
        }
        let later = NudgePlanner.plan(candidates: [nudgeCandidate("c", kind: .hydration)], context: nudgeContext(reservations: ledger))
        #expect(later.notifications.isEmpty)
        #expect(later.silentCards.first?.silentReason == .budgetReached)
    }

    @Test("An unchanged pending ID can be retried without spending a fourth reservation")
    func idempotentRetry() {
        let candidate = nudgeCandidate()
        let ledger = [
            NudgeReservation(id: candidate.id, kind: .mobility, day: testDate(), fireAt: candidate.fireAt),
            NudgeReservation(id: "b", kind: .daylight, day: testDate()),
            NudgeReservation(id: "c", kind: .reset, day: testDate())
        ]
        let result = NudgePlanner.plan(candidates: [candidate], context: nudgeContext(reservations: ledger))
        #expect(result.notifications.map(\.id) == [candidate.id])
    }

    @Test("A reserved ID cannot be recycled at a changed time or with an unknown original time")
    func recycledID() {
        let times: [Date?] = [testDate(2026, 10, 16, 10), nil]
        for fireAt in times {
            let reservation = NudgeReservation(id: "mobility", kind: .mobility, day: testDate(), fireAt: fireAt)
            let result = NudgePlanner.plan(candidates: [nudgeCandidate()], context: nudgeContext(reservations: [reservation]))
            #expect(result.notifications.isEmpty)
            #expect(result.silentCards.first?.silentReason == .alreadyReserved)
        }
    }

    @Test("A new ID for the same automatic foundation does not evade a previous reservation")
    func differentIDsSameKind() {
        let reservation = NudgeReservation(id: "old", kind: .mobility, day: testDate())
        let result = NudgePlanner.plan(candidates: [nudgeCandidate("new")], context: nudgeContext(reservations: [reservation]))
        #expect(result.notifications.isEmpty)
        #expect(result.drops.first?.reason == .alreadyReserved)
    }

    @Test("Explicit snooze consumes another daily reservation and cannot bypass the cap")
    func snoozeBudget() {
        let candidate = nudgeCandidate("snoozed", origin: .snooze(replacingID: "old"))
        let old = NudgeReservation(id: "old", kind: .mobility, day: testDate())
        let first = NudgePlanner.plan(candidates: [candidate], context: nudgeContext(reservations: [old]))
        #expect(first.notifications.map(\.id) == ["snoozed"])
        let ledger = [old, NudgeReservation(id: "b", kind: .reset, day: testDate()),
                      NudgeReservation(id: "c", kind: .hydration, day: testDate())]
        let full = NudgePlanner.plan(candidates: [candidate], context: nudgeContext(reservations: ledger))
        #expect(full.notifications.isEmpty)
        #expect(full.silentCards.first?.silentReason == .budgetReached)
    }

    @Test("Snooze must refer to an existing same-kind reservation from this local day")
    func invalidSnooze() {
        let previous = NudgeReservation(id: "old", kind: .mobility, day: testDate(2026, 10, 15))
        let candidate = nudgeCandidate("new", origin: .snooze(replacingID: "old"))
        let result = NudgePlanner.plan(candidates: [candidate], context: nudgeContext(reservations: [previous]))
        #expect(result.drops.first?.reason == .invalidSnooze)
    }

    @Test("Previous-day IDs do not consume today's three slots")
    func localDayReset() {
        let old = FoundationKind.allCases.map { NudgeReservation(id: $0.rawValue, kind: $0, day: testDate(2026, 10, 15)) }
        let candidates = [nudgeCandidate("a"), nudgeCandidate("b", kind: .daylight), nudgeCandidate("c", kind: .hydration)]
        #expect(NudgePlanner.plan(candidates: candidates, context: nudgeContext(reservations: old)).notifications.count == 3)
    }

    @Test("Zero and negative caller budgets produce only silent updates")
    func noBudget() {
        for budget in [0, -10] {
            let result = NudgePlanner.plan(candidates: [nudgeCandidate()], context: nudgeContext(budget: budget))
            #expect(result.notifications.isEmpty)
            #expect(result.silentCards.first?.silentReason == .budgetReached)
        }
    }

    @Test("Reservation and candidate identity survive local persistence without action authority")
    func valueRoundTrips() throws {
        let value = NudgeReservation(id: "saved", kind: .reset, day: testDate(), fireAt: testDate(2026, 10, 16, 9))
        #expect(try JSONDecoder().decode(NudgeReservation.self, from: JSONEncoder().encode(value)) == value)
        let candidate = nudgeCandidate("later", origin: .snooze(replacingID: "saved"))
        #expect(try JSONDecoder().decode(NudgeCandidate.self, from: JSONEncoder().encode(candidate)) == candidate)
    }

    @Test("Conflicting records under one reservation ID fail closed")
    func conflictingReservations() {
        let ledger = [NudgeReservation(id: "same", kind: .reset, day: testDate()),
                      NudgeReservation(id: "same", kind: .hydration, day: testDate())]
        #expect(NudgePlanner.plan(candidates: [nudgeCandidate()], context: nudgeContext(reservations: ledger)).drops.first?.reason == .invalidContext)
    }
}
