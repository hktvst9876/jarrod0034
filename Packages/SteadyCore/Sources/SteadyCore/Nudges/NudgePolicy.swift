import Foundation

enum NudgePolicy {
    static func dropReason(
        _ candidate: NudgeCandidate, context: NudgePlanningContext, dayStart: Date, dayEnd: Date
    ) -> NudgeDropReason? {
        guard !candidate.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !candidate.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !candidate.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              candidate.durationMinutes > 0, candidate.durationMinutes <= 1_440,
              NudgeWindows.finite(candidate.fireAt), NudgeWindows.finite(candidate.expiresAt),
              candidate.expiresAt > candidate.fireAt else { return .invalidCandidate }
        guard context.enabledKinds.contains(candidate.kind) else { return .disabled }
        guard !context.completedKinds.contains(candidate.kind) else { return .completed }
        guard !SafetyGate.evaluate(context.safetyFlags).blocksPerformanceRecommendations else { return .safetyBlocked }
        guard context.dismissalCounts[candidate.kind, default: 0] < 4 else { return .pausedAfterDismissals }
        guard candidate.fireAt >= context.now else { return .inThePast }
        guard candidate.fireAt >= dayStart && candidate.fireAt < dayEnd else { return .outsideDay }
        if let reservation = context.reservations.first(where: { $0.id == candidate.id }) {
            guard reservation.kind == candidate.kind,
                  context.calendar.isDate(reservation.day, inSameDayAs: dayStart) else { return .invalidCandidate }
        }
        switch candidate.origin {
        case .automatic:
            let other = context.reservations.contains {
                $0.id != candidate.id && $0.kind == candidate.kind
                    && context.calendar.isDate($0.day, inSameDayAs: dayStart)
            }
            if other { return .alreadyReserved }
        case .snooze(let replacingID):
            guard replacingID != candidate.id, context.reservations.contains(where: {
                $0.id == replacingID && $0.kind == candidate.kind
                    && context.calendar.isDate($0.day, inSameDayAs: dayStart)
            }) else { return .invalidSnooze }
        }
        return nil
    }

    static func reducedFrequency(_ candidate: NudgeCandidate, context: NudgePlanningContext, dayStart: Date) -> Bool {
        guard context.dismissalCounts[candidate.kind, default: 0] >= 2 else { return false }
        let lastDay = context.reservations.filter {
            $0.kind == candidate.kind && $0.id != candidate.id
                && context.calendar.startOfDay(for: $0.day) <= dayStart
        }.map { context.calendar.startOfDay(for: $0.day) }.max()
        guard let lastDay,
              let days = context.calendar.dateComponents([.day], from: lastDay, to: dayStart).day else { return false }
        return days < 2
    }

    static func displayCandidate(_ candidate: NudgeCandidate, lowDataMode: Bool) -> NudgeCandidate {
        guard lowDataMode else { return candidate }
        let text: (String, String)
        switch candidate.kind {
        case .mobility: text = ("A comfortable movement moment", "A comfortable movement or rest option is available in Steady.")
        case .daylight: text = ("A daylight moment", "Time outside or in shade is optional. Never look at the sun.")
        case .hydration: text = ("A water cue", "If you are thirsty, consider water with your next meal.")
        case .movementBreak: text = ("An optional pause", "A seated movement or quiet pause is available when it suits you.")
        case .reset: text = ("A quiet moment", "Quiet preparation is available when it suits you.")
        case .windDown: text = ("An optional wind-down", "A small wind-down is available when it suits you.")
        }
        return NudgeCandidate(
            id: candidate.id, kind: candidate.kind, title: text.0, body: text.1,
            fireAt: candidate.fireAt, expiresAt: candidate.expiresAt,
            durationMinutes: candidate.durationMinutes, canWait: candidate.canWait, origin: candidate.origin
        )
    }
}
