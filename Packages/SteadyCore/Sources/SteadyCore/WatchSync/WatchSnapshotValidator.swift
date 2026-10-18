import Foundation

public enum WatchSnapshotAcceptance: Equatable, Sendable {
    case accepted
    case unchanged
    case rejected(WatchRejectionReason)
}

public enum WatchSnapshotValidator {
    /// A durable globally-monotonic revision watermark must survive profile/sample
    /// changes and removal of an expired visible snapshot.
    public static func accept(
        _ snapshot: WatchSnapshot, replacing previous: WatchSnapshot?, minimumRevision: Int = 0,
        clock: any Clock, calendar: Calendar = SteadyCalendar.singapore()
    ) -> WatchSnapshotAcceptance {
        if let issue = issue(in: snapshot, clock: clock, calendar: calendar) { return .rejected(issue) }
        guard snapshot.revision >= minimumRevision else { return .rejected(.staleSnapshot) }
        if let previous {
            if snapshot == previous { return .unchanged }
            if snapshot.id == previous.id { return .rejected(.conflictingReplay) }
            if snapshot.revision <= previous.revision { return .rejected(.staleSnapshot) }
        }
        guard snapshot.revision > minimumRevision else { return .rejected(.staleSnapshot) }
        return .accepted
    }

    public static func issue(
        in snapshot: WatchSnapshot, clock: any Clock,
        calendar: Calendar = SteadyCalendar.singapore()
    ) -> WatchRejectionReason? {
        guard snapshot.schemaVersion == 1 else { return .unsupportedVersion }
        guard WatchPayloadRules.identifier(snapshot.id), snapshot.revision > 0 else { return .invalidIdentifier }
        let now = clock.now
        guard [snapshot.day, snapshot.createdAt, snapshot.expiresAt, now].allSatisfy(WatchPayloadRules.finite) else {
            return .malformedPayload
        }
        guard snapshot.day == calendar.startOfDay(for: snapshot.day),
              calendar.isDate(snapshot.day, inSameDayAs: now),
              calendar.isDate(snapshot.createdAt, inSameDayAs: now) else { return .staleDay }
        guard snapshot.createdAt <= now else { return .futureTimestamp }
        guard snapshot.expiresAt > snapshot.createdAt,
              snapshot.expiresAt.timeIntervalSince(snapshot.createdAt) <= 14_400 else { return .invalidSnapshot }
        guard snapshot.expiresAt > now else { return .expiredSnapshot }
        guard let nextDay = calendar.date(byAdding: .day, value: 1, to: snapshot.day),
              snapshot.expiresAt <= nextDay else { return .invalidSnapshot }
        guard snapshot.alternatives.isEmpty || (2...3).contains(snapshot.alternatives.count),
              Set(snapshot.alternatives.map(\.id)).count == snapshot.alternatives.count,
              snapshot.savedMeals.count <= 3,
              Set(snapshot.savedMeals.map(\.id)).count == snapshot.savedMeals.count,
              Set(snapshot.movementKinds).count == snapshot.movementKinds.count else { return .invalidSnapshot }
        if snapshot.safetyBlocked {
            guard snapshot.plan == nil, snapshot.alternatives.isEmpty,
                  snapshot.foundation == nil, snapshot.movementKinds.isEmpty else { return .invalidSnapshot }
        }
        if snapshot.lowDataMode {
            if let priority = snapshot.priority {
                let expected = snapshot.safetyBlocked
                    ? WatchPriorityCard(title: "Look after yourself", reason: "Pause performance plans and open Steady on iPhone for current safety guidance.")
                    : WatchPriorityCard(title: "Today's priority", reason: "A practical next action; detailed context stays on iPhone.")
                guard priority == expected else { return .invalidSnapshot }
            }
            if let plan = snapshot.plan,
               !PlanType.allCases.map(WatchSnapshotBuilder.lowDataPlanTitle).contains(plan.title) {
                return .invalidSnapshot
            }
            let labels = ["Saved dish A", "Saved dish B", "Saved dish C"]
            guard snapshot.savedMeals.enumerated().allSatisfy({ $0.element.title == labels[$0.offset] }) else {
                return .invalidSnapshot
            }
        }
        if let priority = snapshot.priority {
            guard WatchPayloadRules.text(priority.title), WatchPayloadRules.text(priority.reason) else {
                return .invalidSnapshot
            }
        }
        if let plan = snapshot.plan {
            guard WatchPayloadRules.identifier(plan.id), WatchPayloadRules.text(plan.title),
                  (0...180).contains(plan.minutes), WatchPayloadRules.text(plan.durationExplanation) else {
                return .invalidSnapshot
            }
        }
        if !snapshot.alternatives.isEmpty {
            guard let plan = snapshot.plan, plan.status != .completed,
                  plan.status != .intentionallyRested, plan.status != .deferred else { return .invalidSnapshot }
        }
        guard snapshot.alternatives.allSatisfy({ option in
            WatchPayloadRules.identifier(option.id) && WatchPayloadRules.text(option.title)
                && (1...180).contains(option.minutes) && WatchPayloadRules.text(option.durationExplanation)
                && WatchPayloadRules.text(option.benefitKept) && WatchPayloadRules.text(option.tradeoff)
                && WatchPayloadRules.steps(option.steps)
        }) else { return .invalidSnapshot }
        if let foundation = snapshot.foundation {
            guard WatchPayloadRules.identifier(foundation.optionID), WatchPayloadRules.text(foundation.title),
                  foundation.minutes.map({ (1...30).contains($0) }) ?? true,
                  WatchPayloadRules.text(foundation.durationExplanation), WatchPayloadRules.text(foundation.reason),
                  WatchPayloadRules.steps(foundation.steps) else { return .invalidSnapshot }
        }
        guard snapshot.savedMeals.allSatisfy({
            WatchPayloadRules.identifier($0.id) && WatchPayloadRules.text($0.title)
                && WatchPayloadRules.text($0.uncertainty)
        }) else { return .invalidSnapshot }
        guard (try? WatchWireCodec.encode(snapshot)) != nil else { return .oversizedPayload }
        return nil
    }
}

enum WatchPayloadRules {
    static func finite(_ date: Date) -> Bool { date.timeIntervalSince1970.isFinite }

    static func identifier(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.utf8.count <= 256
            && !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) })
    }

    static func text(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && value.utf8.count <= 2_000
            && !value.unicodeScalars.contains(where: {
                CharacterSet.controlCharacters.contains($0) && $0 != "\n" && $0 != "\t"
            })
    }

    static func steps(_ value: [String]) -> Bool {
        (1...8).contains(value.count) && value.allSatisfy(text)
    }
}
