import Foundation
import Testing
@testable import SteadyCore

struct WeeklyAggregationTests {
    @Test func mondayStartUsesSingaporeDateAcrossUTC() {
        let utcSunday = ISO8601DateFormatter().date(from: "2026-10-18T16:00:00Z")!
        let window = WeeklyWindow.make(containing: utcSunday, now: utcSunday)!
        #expect(weeklyCalendar.component(.weekday, from: window.start) == 2)
        #expect(window.start == testDate(2026, 10, 19))
        #expect(window.endExclusive.timeIntervalSince(window.start) == 7 * 86_400)
    }

    @Test func injectedSundayCalendarStillStartsMonday() {
        var calendar = weeklyCalendar
        calendar.firstWeekday = 1
        #expect(WeeklyWindow.make(containing: weeklyNow, now: weeklyNow, calendar: calendar)?.start == testDate(2026, 10, 12))
    }

    @Test func currentWeekIsPartialAndOnlyElapsedDaysCount() {
        let now = testDate(2026, 10, 14, 9)
        let window = weeklyWindow(now: now)
        #expect(window.elapsedDays == 3)
        #expect(window.isPartial)
        #expect(!window.contains(testDate(2026, 10, 15)))
    }

    @Test func pastWeekIsCompleteAndExclusiveAtNextMonday() {
        let window = WeeklyWindow.make(containing: testDate(2026, 10, 6), now: weeklyNow)!
        #expect(window.elapsedDays == 7)
        #expect(!window.isPartial)
        #expect(!window.contains(testDate(2026, 10, 12)))
    }

    @Test func futureWeekHasNoObservedDaysOrRecords() {
        let window = WeeklyWindow.make(containing: testDate(2026, 10, 20), now: weeklyNow)!
        #expect(window.elapsedDays == 0)
        #expect(!window.contains(window.start))
        #expect(!window.contains(testDate(2026, 10, 20)))
    }

    @Test func missingSleepAndMovementRemainUnknownNotZero() {
        let summary = WeeklyAggregator.summarize(weeklyInput())
        #expect(summary.actualSleepMinutes == nil)
        #expect(summary.sleepOpportunityMinutes == nil)
        #expect(summary.sleepTrackedDays == 0)
        #expect(summary.movementMinutes == nil)
    }

    @Test func actualSleepAndOpportunityHaveSeparateCoverage() {
        let summary = WeeklyAggregator.summarize(weeklyInput(sleep: [
            WeeklySleepObservation(id: "actual", day: testDate(2026, 10, 12), actualMinutes: 420,
                                   opportunityMinutes: nil, source: .health),
            WeeklySleepObservation(id: "opportunity", day: testDate(2026, 10, 13), actualMinutes: nil,
                                   opportunityMinutes: 510, source: .localRecord)
        ]))
        #expect(summary.actualSleepMinutes == 420)
        #expect(summary.sleepOpportunityMinutes == 510)
        #expect(summary.sleepTrackedDays == 1)
        #expect(summary.opportunityTrackedDays == 1)
    }

    @Test func sleepDuplicateIDsAndSameDaySourcesAreNotAdded() {
        let night = WeeklySleepObservation(id: "night", day: testDate(2026, 10, 12), actualMinutes: 400,
                                           opportunityMinutes: 500, source: .health)
        let correction = WeeklySleepObservation(id: "corrected", day: night.day, actualMinutes: 450,
                                                opportunityMinutes: nil, source: .userReported)
        let summary = WeeklyAggregator.summarize(weeklyInput(sleep: [night, night, correction]))
        #expect(summary.actualSleepMinutes == 450)
        #expect(summary.sleepOpportunityMinutes == 500)
        #expect(summary.sleepTrackedDays == 1)
    }

    @Test func conflictingSleepValuesStayUnknownAndIgnoreInvalidRanges() {
        let summary = WeeklyAggregator.summarize(weeklyInput(sleep: [
            WeeklySleepObservation(id: "a", day: testDate(2026, 10, 12), actualMinutes: 400, opportunityMinutes: -1, source: .health),
            WeeklySleepObservation(id: "b", day: testDate(2026, 10, 12), actualMinutes: 430, opportunityMinutes: .nan, source: .health)
        ]))
        #expect(summary.actualSleepMinutes == nil)
        #expect(summary.sleepOpportunityMinutes == nil)
    }

    @Test func realAndSampleObservationsStaySeparated() {
        let values = [
            WeeklyMovementObservation(id: "real", at: weeklyNow, minutes: 20, source: .health),
            WeeklyMovementObservation(id: "sample", at: weeklyNow, minutes: 40, source: .sample)
        ]
        #expect(WeeklyAggregator.summarize(weeklyInput(movement: values)).movementMinutes == 20)
        #expect(WeeklyAggregator.summarize(weeklyInput(scope: weeklyScope(sample: true), movement: values)).movementMinutes == 40)
    }

    @Test func movementIsSourceLabelledDeduplicatedAndBounded() {
        let manual = WeeklyMovementObservation(id: "manual", at: weeklyNow, minutes: 15, source: .userReported)
        let summary = WeeklyAggregator.summarize(weeklyInput(movement: [manual, manual,
            WeeklyMovementObservation(id: "invalid", at: weeklyNow, minutes: -1, source: .userReported),
            WeeklyMovementObservation(id: "future", at: weeklyNow.addingTimeInterval(5), minutes: 60, source: .health)
        ]))
        #expect(summary.movementMinutes == 15)
        #expect(summary.movementEntries == 1)
        #expect(summary.userReportedMovementEntries == 1)
        #expect(summary.healthMovementEntries == 0)
    }

    @Test func conflictingRecordIDsAreOrderIndependentAndNotEvidence() {
        let a = WeeklyMovementObservation(id: "same", at: weeklyNow, minutes: 10, source: .userReported)
        let b = WeeklyMovementObservation(id: "same", at: weeklyNow, minutes: 20, source: .userReported)
        #expect(WeeklyAggregator.summarize(weeklyInput(movement: [a, b])).movementMinutes == nil)
        #expect(WeeklyAggregator.summarize(weeklyInput(movement: [b, a])).movementMinutes == nil)
    }

    @Test func choosingAndRestingAreNotCompletion() {
        let summary = WeeklyAggregator.summarize(weeklyInput(choices: [
            WeeklyChoiceObservation(id: "choose", at: weeklyNow, planID: "plan", kind: .choose, optionID: "small"),
            WeeklyChoiceObservation(id: "rest", at: weeklyNow, planID: "other", kind: .rest)
        ]))
        #expect(summary.alternativesChosen == 1)
        #expect(summary.alternativesCompleted == 0)
        #expect(summary.plansCompleted == 0)
        #expect(summary.plansChanged == 2)
    }

    @Test func alternativeCompletionRequiresPrecedingMatchingChoice() {
        let chosen = WeeklyChoiceObservation(id: "choose", at: weeklyNow.addingTimeInterval(-60), planID: "plan", kind: .choose, optionID: "small")
        let complete = WeeklyChoiceObservation(id: "done", at: weeklyNow, planID: "plan", kind: .complete, optionID: "small")
        let orphan = WeeklyChoiceObservation(id: "other-done", at: weeklyNow, planID: "other", kind: .complete)
        let summary = WeeklyAggregator.summarize(weeklyInput(choices: [chosen, complete, complete, orphan]))
        #expect(summary.alternativesCompleted == 1)
    }

    @Test func completionCannotBeAttributedToAnOptionReplacedBeforeCompletion() {
        let summary = WeeklyAggregator.summarize(weeklyInput(choices: [
            WeeklyChoiceObservation(id: "first", at: weeklyNow.addingTimeInterval(-120), planID: "plan", kind: .choose, optionID: "a"),
            WeeklyChoiceObservation(id: "second", at: weeklyNow.addingTimeInterval(-60), planID: "plan", kind: .choose, optionID: "b"),
            WeeklyChoiceObservation(id: "done", at: weeklyNow, planID: "plan", kind: .complete, optionID: "a")
        ]))
        #expect(summary.alternativesChosen == 2)
        #expect(summary.alternativesCompleted == 0)
    }

    @Test func manyAdaptationsOnOneDayDoNotSupportRepeatedDayProposal() {
        let choices = (0..<5).map { WeeklyChoiceObservation(id: "choice-\($0)", at: weeklyNow,
                                                          planID: "plan-\($0)", kind: .choose, optionID: "small") }
        let summary = WeeklyAggregator.summarize(weeklyInput(choices: choices))
        #expect(summary.changedPlanDays == 1)
        #expect(WeeklyDefaultEngine.proposal(id: "proposal", summary: summary, currentExamMode: false, now: weeklyNow) == nil)
    }

    @Test func foundationDoneCountsDayKindOnceButDismissalsAreEvents() {
        let summary = WeeklyAggregator.summarize(weeklyInput(foundations: [
            WeeklyFoundationObservation(id: "day", day: weeklyNow, kind: .hydration, done: true, dismissed: false),
            WeeklyFoundationObservation(id: "duplicate", day: weeklyNow, kind: .hydration, done: true, dismissed: false),
            WeeklyFoundationObservation(id: "dismissal", day: weeklyNow, kind: .hydration, done: false, dismissed: true)
        ]))
        #expect(summary.foundationsRecorded == 1)
        #expect(summary.foundationsDone == 1)
        #expect(summary.foundationsDismissed == 1)
    }

    @Test func confirmedCorrectionsAreSavedRecordFrequencyNotMealsEaten() {
        let record = WeeklyFoodCorrectionObservation(id: "correction-a", at: weeklyNow, savedDishID: "dish", dishName: "Saved dish")
        let summary = WeeklyAggregator.summarize(weeklyInput(food: [record, record,
            WeeklyFoodCorrectionObservation(id: "correction-b", at: weeklyNow, savedDishID: "dish", dishName: "Saved dish")
        ]))
        #expect(summary.foodCorrections == 2)
        #expect(summary.commonSavedFoods.first?.count == 2)
        #expect(summary.commonSavedFoods.first?.name == "Saved dish")
    }

    @Test func commonSavedFoodDisplayIsCappedWithoutMergingDishIdentity() {
        let records = (0..<5).map { WeeklyFoodCorrectionObservation(id: "record-\($0)", at: weeklyNow,
                                                                 savedDishID: "dish-\($0)", dishName: "Same label") }
        let summary = WeeklyAggregator.summarize(weeklyInput(food: records))
        #expect(summary.foodCorrections == 5)
        #expect(summary.commonSavedFoods.count == 3)
        #expect(Set(summary.commonSavedFoods.map(\.dishID)).count == 3)
    }
}
