import Foundation
@testable import SteadyCore

func foundationState(
    at now: Date = testDate(2026, 10, 16, 10),
    settings: FoundationSettings = FoundationSettings()
) -> FoundationDayState {
    FoundationReducer.startDay(at: now, settings: settings, calendar: testCalendar)
}

func foundationEvent(
    _ kind: FoundationKind, _ action: FoundationAction, id: String = "event",
    day: Date = testDate()
) -> FoundationEvent {
    FoundationEvent(id: id, day: day, kind: kind, action: action)
}

func foundationApply(
    _ event: FoundationEvent, to state: FoundationDayState,
    now: Date = testDate(2026, 10, 16, 10), safetyFlags: [SafetyFlag] = []
) throws -> FoundationDayState {
    try FoundationReducer.apply(event, to: state, now: now, calendar: testCalendar, safetyFlags: safetyFlags)
}
