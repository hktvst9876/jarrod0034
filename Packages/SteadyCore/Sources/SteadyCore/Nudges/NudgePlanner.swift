import Foundation

public enum NudgePlanner {
    /// Pure planning only. Reserve every returned notification ID durably before scheduling.
    /// Existing IDs may be retried, but may never be used for a second action/time.
    public static func plan(candidates: [NudgeCandidate], context: NudgePlanningContext) -> NudgePlanResult {
        guard NudgeWindows.finite(context.now), NudgeWindows.finite(context.day),
              context.calendar.isDate(context.now, inSameDayAs: context.day) else {
            return invalidContext(candidates)
        }
        let dayStart = context.calendar.startOfDay(for: context.day)
        guard let dayEnd = context.calendar.date(byAdding: .day, value: 1, to: dayStart),
              let blocks = NudgeWindows.blocks(context: context, dayStart: dayStart),
              context.reservations.allSatisfy({
                  NudgeWindows.finite($0.day) && ($0.fireAt.map(NudgeWindows.finite) ?? true)
              }),
              validReservations(context.reservations, calendar: context.calendar) else {
            return invalidContext(candidates)
        }
        var seenIDs: Set<String> = []
        var drops: [NudgeDrop] = []
        var ready: [PlannedNudge] = []
        let grouped = Dictionary(grouping: candidates, by: \.id)
        for candidate in candidates {
            guard seenIDs.insert(candidate.id).inserted else {
                drops.append(drop(candidate, .duplicateID)); continue
            }
            guard grouped[candidate.id]?.allSatisfy({ $0 == candidate }) == true else {
                drops.append(drop(candidate, .invalidCandidate)); continue
            }
            if let reason = NudgePolicy.dropReason(candidate, context: context, dayStart: dayStart, dayEnd: dayEnd) {
                drops.append(drop(candidate, reason)); continue
            }
            guard let fireAt = NudgeWindows.firstAvailable(candidate: candidate, blocks: blocks, dayEnd: dayEnd) else {
                drops.append(drop(candidate, .noUnblockedTime)); continue
            }
            ready.append(PlannedNudge(candidate: candidate, fireAt: fireAt))
        }
        ready.sort { $0.fireAt == $1.fireAt ? $0.id < $1.id : $0.fireAt < $1.fireAt }
        var usedIDs = Set(context.reservations.filter {
            context.calendar.isDate($0.day, inSameDayAs: dayStart)
        }.map(\.id))
        let budget = min(3, max(0, context.budget))
        var usedKinds: Set<FoundationKind> = []
        var notifications: [PlannedNudge] = []
        var silentCards: [PlannedNudge] = []
        for planned in ready {
            let candidate = planned.candidate
            guard usedKinds.insert(candidate.kind).inserted else {
                drops.append(drop(candidate, .duplicateKind)); continue
            }
            let reason: NudgeSilentReason?
            if candidate.canWait { reason = .canWait }
            else if !context.notificationPermission { reason = .notificationsUnavailable }
            else if NudgePolicy.reducedFrequency(candidate, context: context, dayStart: dayStart) { reason = .reducedFrequency }
            else if let reserved = context.reservations.first(where: { $0.id == candidate.id }),
                    reserved.fireAt != planned.fireAt { reason = .alreadyReserved }
            else if budget == 0 || (!usedIDs.contains(candidate.id) && usedIDs.count >= budget) { reason = .budgetReached }
            else { reason = nil }
            let result = PlannedNudge(
                candidate: NudgePolicy.displayCandidate(candidate, lowDataMode: context.lowDataMode),
                fireAt: planned.fireAt, silentReason: reason
            )
            if reason != nil { silentCards.append(result) }
            else { notifications.append(result); usedIDs.insert(candidate.id) }
        }
        return NudgePlanResult(notifications: notifications, silentCards: silentCards, drops: drops)
    }

    private static func validReservations(_ reservations: [NudgeReservation], calendar: Calendar) -> Bool {
        for group in Dictionary(grouping: reservations, by: \.id).values {
            guard let first = group.first, !first.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  group.allSatisfy({
                      $0.kind == first.kind && $0.fireAt == first.fireAt
                          && calendar.isDate($0.day, inSameDayAs: first.day)
                  }) else { return false }
        }
        return true
    }

    private static func drop(_ candidate: NudgeCandidate, _ reason: NudgeDropReason) -> NudgeDrop {
        NudgeDrop(candidateID: candidate.id, kind: candidate.kind, reason: reason)
    }

    private static func invalidContext(_ candidates: [NudgeCandidate]) -> NudgePlanResult {
        NudgePlanResult(notifications: [], silentCards: [], drops: candidates.map { drop($0, .invalidContext) })
    }
}
