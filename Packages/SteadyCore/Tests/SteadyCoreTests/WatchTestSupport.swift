import Foundation
@testable import SteadyCore

let watchProfileID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
let watchNow = testDate(2026, 10, 18, 12, 0)
let watchClock = FixedClock(now: watchNow)

func watchPlan(title: String = "A comfortable walk", status: PlanStatus = .proposed) -> PlanItem {
    PlanItem(id: "watch-plan", day: testDate(2026, 10, 18), type: .walk, title: title,
             outcome: advisorOutcome(), minutes: 20, slot: nil, status: status, origin: .user)
}

func watchOptions() -> AlternativeSet {
    AlternativeSet(planID: "watch-plan", barrier: .anotherOption, options: [
        alternativeOption("watch-a", effort: .minimal, minutes: 3),
        alternativeOption("watch-b", effort: .light, minutes: 5),
        alternativeOption("watch-c", effort: .moderate, minutes: 10)
    ], source: .fallback)
}

func watchSnapshot(
    id: String = "snapshot-one", revision: Int = 1, profileID: UUID = watchProfileID,
    sample: Bool = false, lowDataMode: Bool = false, safetyBlocked: Bool = false,
    plan: PlanItem = watchPlan(), clock: any Clock = watchClock
) -> WatchSnapshot {
    WatchSnapshotBuilder.make(
        id: id, revision: revision, profileID: profileID, useSampleData: sample,
        priority: DailyPriority(kind: .recover, ruleID: "private-rule", title: "Private health title",
                                explanation: Explanation(summary: "private sleep 123 and recovery 456"), planA: plan),
        plan: plan, alternatives: watchOptions(),
        foundation: FoundationCatalog.options(for: .hydration, settings: FoundationSettings()).first,
        savedMeals: [WatchSavedMealCard(id: "saved-meal", title: "Private meal 789 calories")],
        movementKinds: WatchMovementKind.allCases, lowDataMode: lowDataMode,
        safetyBlocked: safetyBlocked, clock: clock
    )
}

func watchReplacing(
    _ original: WatchSnapshot, schemaVersion: Int? = nil, id: String? = nil,
    revision: Int? = nil, profileID: UUID? = nil, sample: Bool? = nil,
    day: Date? = nil, createdAt: Date? = nil, expiresAt: Date? = nil,
    lowDataMode: Bool? = nil, safetyBlocked: Bool? = nil, priority: WatchPriorityCard? = nil,
    alternatives: [WatchAlternativeCard]? = nil, savedMeals: [WatchSavedMealCard]? = nil
) -> WatchSnapshot {
    WatchSnapshot(
        schemaVersion: schemaVersion ?? original.schemaVersion, id: id ?? original.id,
        revision: revision ?? original.revision, profileID: profileID ?? original.profileID,
        useSampleData: sample ?? original.useSampleData, day: day ?? original.day,
        createdAt: createdAt ?? original.createdAt, expiresAt: expiresAt ?? original.expiresAt,
        lowDataMode: lowDataMode ?? original.lowDataMode, safetyBlocked: safetyBlocked ?? original.safetyBlocked,
        priority: priority ?? original.priority, plan: original.plan,
        alternatives: alternatives ?? original.alternatives, foundation: original.foundation,
        savedMeals: savedMeals ?? original.savedMeals, movementKinds: original.movementKinds
    )
}

func watchAction(
    id: String = "action-one", snapshot: WatchSnapshot = watchSnapshot(),
    profileID: UUID? = nil, sample: Bool? = nil, day: Date? = nil, createdAt: Date = watchNow,
    kind: WatchActionKind = .chooseAlternative(optionID: "watch-a")
) -> WatchAction {
    WatchAction(id: id, snapshotID: snapshot.id, snapshotRevision: snapshot.revision,
                profileID: profileID ?? snapshot.profileID, useSampleData: sample ?? snapshot.useSampleData,
                day: day ?? snapshot.day, createdAt: createdAt, kind: kind)
}

func watchEvaluate(
    _ action: WatchAction, snapshot: WatchSnapshot = watchSnapshot(),
    current: WatchCurrentContext? = nil, receipts: [WatchActionReceipt] = [], clock: any Clock = watchClock
) -> WatchActionDecision {
    WatchActionValidator.evaluate(action, snapshot: snapshot,
                                  current: current ?? WatchCurrentContext(snapshot: snapshot),
                                  receipts: receipts, clock: clock)
}
