import Foundation
import Testing
@testable import SteadyCore

@Suite("Nudge suppression and wording")
struct NudgePolicyTests {
    @Test("Denied notifications leave a silent Today card rather than blocking the foundation")
    func permissionFallback() {
        let result = NudgePlanner.plan(candidates: [nudgeCandidate()], context: nudgeContext(permission: false))
        #expect(result.notifications.isEmpty)
        #expect(result.silentCards.first?.silentReason == .notificationsUnavailable)
    }

    @Test("An action that can wait prefers silent Today even when notifications are authorized")
    func canWait() {
        let result = NudgePlanner.plan(candidates: [nudgeCandidate(canWait: true)], context: nudgeContext())
        #expect(result.notifications.isEmpty)
        #expect(result.silentCards.first?.silentReason == .canWait)
    }

    @Test("Disabled and completed foundation types produce typed drops")
    func disabledAndDone() {
        let disabled = nudgeContext(enabled: [.daylight])
        #expect(NudgePlanner.plan(candidates: [nudgeCandidate()], context: disabled).drops.first?.reason == .disabled)
        let done = nudgeContext(completed: [.mobility])
        #expect(NudgePlanner.plan(candidates: [nudgeCandidate()], context: done).drops.first?.reason == .completed)
    }

    @Test("A newly reported safety symptom suppresses every proactive or silent action")
    func safetyFirst() {
        let context = nudgeContext(safety: [.userReported(.chestSymptoms)])
        let result = NudgePlanner.plan(candidates: [nudgeCandidate(canWait: true)], context: context)
        #expect(result.notifications.isEmpty && result.silentCards.isEmpty)
        #expect(result.drops.first?.reason == .safetyBlocked)
    }

    @Test("Zero and one dismissal retain normal frequency")
    func normalDismissalFrequency() {
        for count in [0, 1] {
            let old = NudgeReservation(id: "yesterday", kind: .mobility, day: testDate(2026, 10, 15))
            let context = nudgeContext(dismissals: [.mobility: count], reservations: [old])
            #expect(NudgePlanner.plan(candidates: [nudgeCandidate()], context: context).notifications.count == 1)
        }
    }

    @Test("Two dismissals reduce frequency to every other local day")
    func reducedFrequencyCooldown() {
        let yesterday = NudgeReservation(id: "old", kind: .mobility, day: testDate(2026, 10, 15, 12))
        let first = NudgePlanner.plan(candidates: [nudgeCandidate()], context: nudgeContext(dismissals: [.mobility: 2], reservations: [yesterday]))
        #expect(first.notifications.isEmpty)
        #expect(first.silentCards.first?.silentReason == .reducedFrequency)
        let twoDaysAgo = NudgeReservation(id: "old", kind: .mobility, day: testDate(2026, 10, 14))
        let later = NudgePlanner.plan(candidates: [nudgeCandidate()], context: nudgeContext(dismissals: [.mobility: 2], reservations: [twoDaysAgo]))
        #expect(later.notifications.count == 1)
    }

    @Test("Four dismissals pause the type until an explicit user reset")
    func pausedAndResumed() {
        let paused = NudgePlanner.plan(candidates: [nudgeCandidate()], context: nudgeContext(dismissals: [.mobility: 4]))
        #expect(paused.drops.first?.reason == .pausedAfterDismissals)
        #expect(paused.notifications.isEmpty && paused.silentCards.isEmpty)
        let resumed = NudgePlanner.plan(candidates: [nudgeCandidate()], context: nudgeContext(dismissals: [.mobility: 0]))
        #expect(resumed.notifications.count == 1)
    }

    @Test("Snooze cannot bypass a paused dismissal policy")
    func snoozeRespectsPause() {
        let old = NudgeReservation(id: "old", kind: .mobility, day: testDate())
        let candidate = nudgeCandidate("snoozed", origin: .snooze(replacingID: "old"))
        let result = NudgePlanner.plan(candidates: [candidate], context: nudgeContext(dismissals: [.mobility: 4], reservations: [old]))
        #expect(result.drops.first?.reason == .pausedAfterDismissals)
    }

    @Test("Low-data output replaces score, calorie, and weight wording with fixed neutral copy")
    func lowDataWording() {
        for kind in FoundationKind.allCases {
            let candidate = NudgeCandidate(id: kind.rawValue, kind: kind, title: "Weight and readiness 80",
                                           body: "Calories 900, recovery is low", fireAt: testDate(2026, 10, 16, 9),
                                           expiresAt: testDate(2026, 10, 16, 20), durationMinutes: 3, canWait: false)
            let planned = NudgePlanner.plan(candidates: [candidate], context: nudgeContext(lowData: true)).notifications.first
            let copy = ((planned?.title ?? "") + (planned?.body ?? "")).lowercased()
            #expect(!copy.isEmpty)
            for sensitive in ["weight", "readiness", "calorie", "recovery", "900", "80"] { #expect(!copy.contains(sensitive)) }
        }
    }

    @Test("Duplicate IDs and multiple automatic candidates of a kind do not create repeat prompts")
    func duplicateCandidates() {
        let first = nudgeCandidate("a")
        let result = NudgePlanner.plan(candidates: [first, first, nudgeCandidate("b")], context: nudgeContext())
        #expect(result.notifications.count == 1)
        #expect(result.drops.map(\.reason) == [.duplicateID, .duplicateKind])
    }

    @Test("Conflicting payloads under one ID are rejected rather than choosing an arbitrary action")
    func conflictingPayloads() {
        let result = NudgePlanner.plan(candidates: [nudgeCandidate("same"), nudgeCandidate("same", hour: 10)], context: nudgeContext())
        #expect(result.notifications.isEmpty)
        #expect(result.drops.first?.reason == .invalidCandidate)
    }

    @Test("Only ordinary notification interruption metadata can be emitted")
    func ordinaryInterruption() {
        let result = NudgePlanner.plan(candidates: [nudgeCandidate()], context: nudgeContext())
        #expect(result.notifications.allSatisfy { $0.interruptionLevel == .ordinary })
    }

    @Test("A stale planning day cannot write today's notification budget")
    func wrongPlanningDay() {
        let context = NudgePlanningContext(now: testDate(2026, 10, 17, 8), day: testDate(), notificationPermission: true)
        #expect(NudgePlanner.plan(candidates: [nudgeCandidate()], context: context).drops.first?.reason == .invalidContext)
    }
}
