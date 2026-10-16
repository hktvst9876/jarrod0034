import Foundation
import Testing
@testable import SteadyCore

@Suite("Daily priority P0-P8")
struct DailyPriorityEngineTests {
    @Test("P0 safety overrides every rule and a user selection")
    func p0SafetyOverride() {
        let context = testContext(
            sleepMinutes: 5 * 60,
            recoveryStatus: .goEasier,
            safetyFlags: [.userReported(.chestSymptoms)],
            strengthTarget: 3,
            daysLeft: 1,
            plannedStrengthDay: true,
            userSelectedPriority: .strength
        )
        let result = DailyPriorityEngine.select(for: context)
        #expect(result.ruleID == "P0")
        #expect(result.kind == .lookAfterYourself)
        #expect(result.planA.type == .rest)
        #expect(!result.chosenByUser)
    }

    @Test("A user selection overrides non-safety automatic rules")
    func userSelection() {
        let result = DailyPriorityEngine.select(
            for: testContext(sleepMinutes: 5 * 60, userSelectedPriority: .getMoving)
        )
        #expect(result.ruleID == "U0")
        #expect(result.kind == .getMoving)
        #expect(result.chosenByUser)
    }

    @Test("P1 short sleep wins before recovery")
    func p1ShortSleepAndOrder() {
        let result = DailyPriorityEngine.select(
            for: testContext(sleepMinutes: 5 * 60 + 40, recoveryStatus: .goEasier)
        )
        #expect(result.ruleID == "P1")
        #expect(result.kind == .protectBedtime)
        #expect(result.explanation.summary.contains("5 h 40 min"))
    }

    @Test("P1 also uses seven-day shortfall")
    func p1Shortfall() {
        let result = DailyPriorityEngine.select(
            for: testContext(sleepMinutes: 8 * 60, shortfallMinutes: 5 * 60)
        )
        #expect(result.ruleID == "P1")
        #expect(result.explanation.factors.first?.displayValue == "5 h")
    }

    @Test("Exam mode changes P1 short-night threshold to one hour")
    func p1ExamThreshold() {
        let ordinary = DailyPriorityEngine.select(for: testContext(sleepMinutes: 6 * 60 + 45))
        let exam = DailyPriorityEngine.select(
            for: testContext(sleepMinutes: 6 * 60 + 45, examMode: true)
        )
        #expect(ordinary.ruleID == "P8")
        #expect(exam.ruleID == "P1")
    }

    @Test("P2 handles a go-easier context")
    func p2Recovery() {
        let result = DailyPriorityEngine.select(for: testContext(recoveryStatus: .goEasier))
        #expect(result.ruleID == "P2")
        #expect(result.kind == .recover)
    }

    @Test("P2 handles a user reporting soreness")
    func p2Sore() {
        let result = DailyPriorityEngine.select(for: testContext(checkIn: .sore))
        #expect(result.ruleID == "P2")
        #expect(result.explanation.summary.contains("sore"))
    }

    @Test("P3 uses a short-on-time check-in")
    func p3CheckIn() {
        let result = DailyPriorityEngine.select(
            for: testContext(freeMinutes: nil, checkIn: .shortOnTime)
        )
        #expect(result.ruleID == "P3")
        #expect(result.planA.minutes == 10)
    }

    @Test("P3 free time wins before strength pressure")
    func p3Order() {
        let result = DailyPriorityEngine.select(
            for: testContext(
                freeMinutes: 35,
                strengthTarget: 3,
                daysLeft: 1,
                plannedStrengthDay: true
            )
        )
        #expect(result.ruleID == "P3")
        #expect(result.explanation.summary.contains("35"))
    }

    @Test("P4 schedules a concrete strength slot in the preferred period")
    func p4Strength() throws {
        let result = DailyPriorityEngine.select(
            for: testContext(
                strengthDone: 1,
                strengthTarget: 3,
                daysLeft: 4,
                plannedStrengthDay: true
            )
        )
        let slot = try #require(result.planA.slot)
        #expect(result.ruleID == "P4")
        #expect(result.kind == .strength)
        #expect(slot.start == testDate(2026, 10, 16, 12))
        #expect(slot.end == testDate(2026, 10, 16, 12, 45))
    }

    @Test("P4 never schedules strength on consecutive days")
    func p4ConsecutiveDayGuard() {
        let result = DailyPriorityEngine.select(
            for: testContext(
                strengthTarget: 3,
                daysLeft: 1,
                strengthYesterday: true,
                plannedStrengthDay: true
            )
        )
        #expect(result.ruleID == "P8")
    }

    @Test("P4 is condensed in exam mode")
    func p4ExamMode() {
        let result = DailyPriorityEngine.select(
            for: testContext(
                strengthTarget: 3,
                daysLeft: 1,
                plannedStrengthDay: true,
                examMode: true
            )
        )
        #expect(result.ruleID == "P4")
        #expect(result.planA.minutes == 25)
    }

    @Test("P5 responds after two days without exercise")
    func p5GetMoving() {
        let result = DailyPriorityEngine.select(for: testContext(daysSinceExercise: 2))
        #expect(result.ruleID == "P5")
        #expect(result.kind == .getMoving)
    }

    @Test("P6 keeps a stressful day lighter")
    func p6LighterDay() {
        let result = DailyPriorityEngine.select(for: testContext(checkIn: .stressed))
        #expect(result.ruleID == "P6")
        #expect(result.kind == .lighterDay)
    }

    @Test("P7 follows a plan and puts its short version first for low energy")
    func p7PlannedItem() {
        let result = DailyPriorityEngine.select(
            for: testContext(checkIn: .lowEnergy, plannedToday: testPlan(minutes: 50))
        )
        #expect(result.ruleID == "P7")
        #expect(result.planA.minutes == 25)
        #expect(result.planA.origin == .condensed)
    }

    @Test("P8 is a neutral steady day")
    func p8Default() {
        let result = DailyPriorityEngine.select(for: testContext())
        #expect(result.ruleID == "P8")
        #expect(result.kind == .steadyDay)
    }

    @Test("Denied or empty Health data uses the chosen focus before catch-up strength")
    func missingHealthFallback() {
        let result = DailyPriorityEngine.select(
            for: testContext(
                sleepMinutes: nil,
                shortfallMinutes: nil,
                daysSinceExercise: nil,
                strengthTarget: 3,
                daysLeft: 1,
                plannedStrengthDay: true,
                fallbackFocus: .sleep,
                dataGaps: [.sleep, .activity]
            )
        )
        #expect(result.ruleID == "F0")
        #expect(result.kind == .protectBedtime)
        #expect(result.chosenByUser)
    }

    @Test("Manual stress check-in still works when Health is denied")
    func missingHealthUsesCheckIn() {
        let result = DailyPriorityEngine.select(
            for: testContext(
                sleepMinutes: nil,
                shortfallMinutes: nil,
                daysSinceExercise: nil,
                checkIn: .stressed,
                fallbackFocus: .sleep,
                dataGaps: [.healthPermissions]
            )
        )
        #expect(result.ruleID == "P6")
    }

    @Test("A recovered label never makes the plan more intense")
    func recoveredDoesNotIntensify() {
        let normal = DailyPriorityEngine.select(
            for: testContext(recoveryStatus: .normal, strengthTarget: 3, daysLeft: 1)
        )
        let recovered = DailyPriorityEngine.select(
            for: testContext(recoveryStatus: .recovered, strengthTarget: 3, daysLeft: 1)
        )
        #expect(normal.kind == recovered.kind)
        #expect(normal.planA.minutes == recovered.planA.minutes)
    }

    @Test("Identical inputs produce identical output")
    func deterministic() {
        let context = testContext(strengthTarget: 3, daysLeft: 1)
        #expect(DailyPriorityEngine.select(for: context) == DailyPriorityEngine.select(for: context))
    }
}
