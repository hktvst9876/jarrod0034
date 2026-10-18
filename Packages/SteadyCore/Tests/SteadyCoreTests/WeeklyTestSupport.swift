import Foundation
@testable import SteadyCore

let weeklyNow = testDate(2026, 10, 18, 12, 0)
let weeklyProfileID = UUID(uuidString: "77777777-2222-3333-4444-555555555555")!
let weeklyCalendar = SteadyCalendar.singapore()

func weeklyScope(sample: Bool = false, revision: String = "revision-a", weekStart: Date = testDate(2026, 10, 12)) -> WeeklyScope {
    WeeklyScope(profileID: weeklyProfileID, isSample: sample, weekStart: weekStart, revision: revision)
}

func weeklyWindow(now: Date = weeklyNow) -> WeeklyWindow {
    WeeklyWindow.make(containing: now, now: now, calendar: weeklyCalendar)!
}

func weeklyInput(
    scope: WeeklyScope = weeklyScope(), window: WeeklyWindow = weeklyWindow(),
    sleep: [WeeklySleepObservation] = [], movement: [WeeklyMovementObservation] = [],
    plans: [WeeklyPlanObservation] = [], choices: [WeeklyChoiceObservation] = [],
    foundations: [WeeklyFoundationObservation] = [], food: [WeeklyFoodCorrectionObservation] = [],
    metrics: [WeeklyMetricEvent] = []
) -> WeeklyInput {
    WeeklyInput(scope: scope, window: window, sleep: sleep, movement: movement, plans: plans,
                choices: choices, foundations: foundations, foodCorrections: food, metrics: metrics)
}

func weeklyEvidenceSummary(now: Date = weeklyNow) -> WeeklySummary {
    WeeklyAggregator.summarize(weeklyInput(window: weeklyWindow(now: now), plans: [
        WeeklyPlanObservation(id: "plan-a", day: testDate(2026, 10, 12), completed: false, changed: true),
        WeeklyPlanObservation(id: "plan-b", day: testDate(2026, 10, 13), completed: false, changed: true),
        WeeklyPlanObservation(id: "plan-c", day: testDate(2026, 10, 14), completed: false, changed: true)
    ]))
}

func weeklyProposal() -> WeeklyDefaultProposal {
    WeeklyDefaultEngine.proposal(id: "proposal-a", summary: weeklyEvidenceSummary(),
                                 currentExamMode: false, now: weeklyNow)!
}

func weeklyDraft(
    id: String = "experiment-a", scope: WeeklyScope = weeklyScope(),
    start: Date = testDate(2026, 10, 18), end: Date = testDate(2026, 10, 25), preparedAt: Date = weeklyNow
) -> WeeklyExperimentDraft {
    WeeklyExperimentDraft(id: id, scope: scope, kind: .smallPlan, start: start, endExclusive: end, preparedAt: preparedAt)
}

func weeklyMetric(_ id: String, _ kind: WeeklyMetricKind, subject: String = "subject-a",
                  at: Date = weeklyNow, seconds: Double? = nil, helpfulness: WeeklyHelpfulness? = nil) -> WeeklyMetricEvent {
    WeeklyMetricEvent(id: id, at: at, kind: kind, subjectID: subject, decisionSeconds: seconds, helpfulness: helpfulness)
}
