import Foundation
import Testing
@testable import SteadyCore

struct WeeklyExperimentTests {
    @Test func savingSelectedExperimentHasBoundedDatesAndSimpleMeasure() throws {
        let experiment = try WeeklyExperimentReducer.save(weeklyDraft(), currentScope: weeklyScope(), existing: nil, now: weeklyNow)
        #expect(experiment.kind == .smallPlan)
        #expect(experiment.endExclusive == testDate(2026, 10, 25))
        #expect(experiment.createdAt == weeklyNow)
        #expect(!experiment.kind.simpleMeasure.isEmpty)
        #expect(WeeklyExperimentKind.allCases.allSatisfy { !$0.title.isEmpty && !$0.simpleMeasure.isEmpty })
    }

    @Test func sampleAndProfileAndRevisionChangesRejectSave() {
        for scope in [weeklyScope(sample: true), weeklyScope(revision: "b")] {
            #expect(throws: WeeklyLearningError.staleScope) {
                try WeeklyExperimentReducer.save(weeklyDraft(), currentScope: scope, existing: nil, now: weeklyNow)
            }
        }
    }

    @Test func onlyOneActiveOrFutureExperimentCanBeSaved() throws {
        let existing = try WeeklyExperimentReducer.save(weeklyDraft(), currentScope: weeklyScope(), existing: nil, now: weeklyNow)
        #expect(throws: WeeklyLearningError.overlappingExperiment) {
            try WeeklyExperimentReducer.save(weeklyDraft(id: "another"), currentScope: weeklyScope(), existing: existing, now: weeklyNow)
        }
    }

    @Test func exactSameIDSaveIsIdempotentButDifferentDatesConflict() throws {
        let existing = try WeeklyExperimentReducer.save(weeklyDraft(), currentScope: weeklyScope(), existing: nil, now: weeklyNow)
        #expect(try WeeklyExperimentReducer.save(weeklyDraft(), currentScope: weeklyScope(), existing: existing, now: weeklyNow) == existing)
        #expect(throws: WeeklyLearningError.conflictingID) {
            try WeeklyExperimentReducer.save(weeklyDraft(end: testDate(2026, 10, 24)), currentScope: weeklyScope(), existing: existing, now: weeklyNow)
        }
    }

    @Test func experimentMustBeTwoToFourteenWholeLocalDays() {
        let invalid = [
            weeklyDraft(end: testDate(2026, 10, 19)), weeklyDraft(end: testDate(2026, 11, 2)),
            weeklyDraft(start: testDate(2026, 10, 17)), weeklyDraft(start: testDate(2026, 10, 18, 8)),
            weeklyDraft(start: testDate(2026, 10, 26), end: testDate(2026, 11, 1))
        ]
        for draft in invalid {
            #expect(throws: WeeklyLearningError.invalidDates) {
                try WeeklyExperimentReducer.save(draft, currentScope: weeklyScope(), existing: nil, now: weeklyNow)
            }
        }
    }

    @Test func experimentFromLastWeekReviewCanStartToday() throws {
        let scope = weeklyScope(weekStart: testDate(2026, 10, 5))
        let result = try WeeklyExperimentReducer.save(weeklyDraft(scope: scope), currentScope: scope, existing: nil, now: weeklyNow)
        #expect(result.scope.weekStart == testDate(2026, 10, 5))
        #expect(result.start == testDate(2026, 10, 18))
    }

    @Test func expiredDraftDoesNotWriteAnExperiment() {
        #expect(throws: WeeklyLearningError.expired) {
            try WeeklyExperimentReducer.save(weeklyDraft(preparedAt: weeklyNow.addingTimeInterval(-1_801)),
                                              currentScope: weeklyScope(), existing: nil, now: weeklyNow)
        }
    }

    @Test func endedExperimentDoesNotBlockNewExplicitSave() throws {
        let previous = WeeklyExperiment(id: "old", scope: weeklyScope(), kind: .windDown,
                                        start: testDate(2026, 10, 10), endExclusive: testDate(2026, 10, 17),
                                        createdAt: testDate(2026, 10, 10))
        let next = try WeeklyExperimentReducer.save(weeklyDraft(), currentScope: weeklyScope(), existing: previous, now: weeklyNow)
        #expect(next.id == "experiment-a")
    }

    @Test func cancelRequiresCapturedFreshScopeAndDoesNotMutateInput() throws {
        let experiment = try WeeklyExperimentReducer.save(weeklyDraft(), currentScope: weeklyScope(), existing: nil, now: weeklyNow)
        #expect(throws: WeeklyLearningError.staleScope) {
            try WeeklyExperimentReducer.cancel(experiment, capturedScope: weeklyScope(), currentScope: weeklyScope(revision: "new"),
                                                preparedAt: weeklyNow, now: weeklyNow)
        }
        try WeeklyExperimentReducer.cancel(experiment, capturedScope: weeklyScope(), currentScope: weeklyScope(),
                                            preparedAt: weeklyNow, now: weeklyNow)
        #expect(experiment.id == "experiment-a")
    }
}
