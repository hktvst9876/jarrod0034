import Foundation
import Testing
@testable import SteadyCore

@Suite("Nudge bounded availability")
struct NudgeWindowTests {
    @Test("Candidates move beyond calendar, workout and sleep blocks in sequence")
    func allBlockSources() {
        let context = nudgeContext(calendarBlocks: [nudgeBlock(9, 10)], workouts: [nudgeBlock(10, 11)], sleep: [nudgeBlock(11, 12)])
        let result = NudgePlanner.plan(candidates: [nudgeCandidate()], context: context)
        #expect(result.notifications.first?.fireAt == testDate(2026, 10, 16, 12))
    }

    @Test("The whole action must fit; a free notification instant alone is insufficient")
    func fullActionDuration() {
        let candidate = nudgeCandidate(hour: 8, minute: 58, minutes: 3)
        let result = NudgePlanner.plan(candidates: [candidate], context: nudgeContext(calendarBlocks: [nudgeBlock(9, 10)]))
        #expect(result.notifications.first?.fireAt == testDate(2026, 10, 16, 10))
    }

    @Test("Half-open boundaries allow ending at a block start or starting at its end")
    func exactBoundaries() {
        let context = nudgeContext(calendarBlocks: [nudgeBlock(9, 10)])
        let ending = nudgeCandidate(hour: 8, minute: 57, minutes: 3)
        #expect(NudgePlanner.plan(candidates: [ending], context: context).notifications.first?.fireAt == ending.fireAt)
        let starting = nudgeCandidate(hour: 10)
        #expect(NudgePlanner.plan(candidates: [starting], context: context).notifications.first?.fireAt == starting.fireAt)
    }

    @Test("Moving never carries an action past its bounded expiry")
    func expiryBound() {
        let candidate = NudgeCandidate(id: "bounded", kind: .mobility, title: "Pause", body: "Optional pause",
                                       fireAt: testDate(2026, 10, 16, 9), expiresAt: testDate(2026, 10, 16, 10, 2),
                                       durationMinutes: 3, canWait: false)
        let result = NudgePlanner.plan(candidates: [candidate], context: nudgeContext(calendarBlocks: [nudgeBlock(9, 10)]))
        #expect(result.notifications.isEmpty)
        #expect(result.drops.first?.reason == .noUnblockedTime)
    }

    @Test("Cross-midnight quiet periods include the previous day's occurrence")
    func midnightQuietMorning() {
        let candidate = nudgeCandidate(hour: 6)
        let context = nudgeContext(hour: 0, quiet: [NudgeQuietPeriod(startMinute: 22 * 60, endMinute: 7 * 60)])
        #expect(NudgePlanner.plan(candidates: [candidate], context: context).notifications.first?.fireAt == testDate(2026, 10, 16, 7))
    }

    @Test("A late quiet period cannot push today's notification into tomorrow's budget")
    func midnightCannotEscapeDay() {
        let candidate = NudgeCandidate(id: "late", kind: .windDown, title: "Wind-down", body: "Optional wind-down",
                                       fireAt: testDate(2026, 10, 16, 22), expiresAt: testDate(2026, 10, 17, 8),
                                       durationMinutes: 3, canWait: false)
        let context = nudgeContext(quiet: [NudgeQuietPeriod(startMinute: 22 * 60, endMinute: 7 * 60)])
        #expect(NudgePlanner.plan(candidates: [candidate], context: context).drops.first?.reason == .noUnblockedTime)
    }

    @Test("Equal quiet endpoints mean quiet all day rather than an empty block")
    func allDayQuiet() {
        let result = NudgePlanner.plan(candidates: [nudgeCandidate()], context: nudgeContext(quiet: [NudgeQuietPeriod(startMinute: 0, endMinute: 0)]))
        #expect(result.drops.first?.reason == .noUnblockedTime)
    }

    @Test("Overlapping blocks are handled without finding a false free gap")
    func overlappingBlocks() {
        let blocks = [nudgeBlock(9, 11), nudgeBlock(10, 12), nudgeBlock(11, 13)]
        let result = NudgePlanner.plan(candidates: [nudgeCandidate()], context: nudgeContext(calendarBlocks: blocks))
        #expect(result.notifications.first?.fireAt == testDate(2026, 10, 16, 13))
    }

    @Test("Notification priority follows final available times, then stable IDs")
    func effectiveOrdering() {
        let candidates = [nudgeCandidate("later", hour: 9, minutes: 60),
                          nudgeCandidate("earlier", kind: .daylight, hour: 9, minute: 30, minutes: 3)]
        let shortBlock = DateRange(start: testDate(2026, 10, 16, 9, 45), end: testDate(2026, 10, 16, 12))
        let result = NudgePlanner.plan(candidates: candidates, context: nudgeContext(calendarBlocks: [shortBlock], budget: 1))
        #expect(result.notifications.map(\.id) == ["earlier"])
        #expect(result.silentCards.first?.id == "later")
    }

    @Test("Malformed quiet periods or blocks fail closed rather than silently ignoring restrictions")
    func invalidBlocks() {
        let quiet = nudgeContext(quiet: [NudgeQuietPeriod(startMinute: -1, endMinute: 60)])
        #expect(NudgePlanner.plan(candidates: [nudgeCandidate()], context: quiet).drops.first?.reason == .invalidContext)
        let backwards = nudgeContext(calendarBlocks: [nudgeBlock(11, 9)])
        #expect(NudgePlanner.plan(candidates: [nudgeCandidate()], context: backwards).drops.first?.reason == .invalidContext)
    }

    @Test("Non-finite or inverted candidate dates never reach date arithmetic")
    func invalidCandidateDates() {
        let invalid = NudgeCandidate(id: "invalid", kind: .reset, title: "Pause", body: "Optional",
                                     fireAt: Date(timeIntervalSinceReferenceDate: .nan), expiresAt: testDate(2026, 10, 16, 20),
                                     durationMinutes: Int.max, canWait: false)
        #expect(NudgePlanner.plan(candidates: [invalid], context: nudgeContext()).drops.first?.reason == .invalidCandidate)
    }

    @Test("Past and other-day candidates are not silently moved back into the queue")
    func elapsedOrOtherDay() {
        #expect(NudgePlanner.plan(candidates: [nudgeCandidate(hour: 7)], context: nudgeContext()).drops.first?.reason == .inThePast)
        #expect(NudgePlanner.plan(candidates: [nudgeCandidate(day: 17)], context: nudgeContext()).drops.first?.reason == .outsideDay)
    }

    @Test("Snooze still respects quiet windows and full action duration")
    func snoozeWindows() {
        let candidate = nudgeCandidate("snoozed", origin: .snooze(replacingID: "old"))
        let ledger = [NudgeReservation(id: "old", kind: .mobility, day: testDate())]
        let context = nudgeContext(quiet: [NudgeQuietPeriod(startMinute: 9 * 60, endMinute: 10 * 60)], reservations: ledger)
        #expect(NudgePlanner.plan(candidates: [candidate], context: context).notifications.first?.fireAt == testDate(2026, 10, 16, 10))
    }

    @Test("Negative, zero and overflowing durations are typed invalid candidates")
    func invalidDurations() {
        for duration in [-1, 0, Int.max] {
            let result = NudgePlanner.plan(candidates: [nudgeCandidate(minutes: duration)], context: nudgeContext())
            #expect(result.drops.first?.reason == .invalidCandidate)
        }
    }

    @Test("Malformed current time is rejected before Calendar conversion")
    func nonFiniteContext() {
        let context = NudgePlanningContext(now: Date(timeIntervalSinceReferenceDate: .infinity), day: testDate())
        #expect(NudgePlanner.plan(candidates: [nudgeCandidate()], context: context).drops.first?.reason == .invalidContext)
    }
}
