import Foundation

public enum ReschedulePlanner {
    public static func proposals(
        for plan: PlanItem,
        slots: [FreeSlot],
        notBefore: Date,
        safetyFlags: [SafetyFlag] = [],
        limit: Int = 3
    ) -> [RescheduleProposal] {
        guard !SafetyGate.evaluate(safetyFlags).blocksPerformanceRecommendations,
              plan.minutes > 0,
              plan.status != .completed,
              plan.status != .intentionallyRested,
              plan.type != .rest,
              limit > 0 else { return [] }

        let duration = Double(plan.minutes) * 60
        var seen = Set<String>()
        return slots.compactMap { slot -> RescheduleProposal? in
            guard slot.confidence != .unknown else { return nil }
            let earliest = max(slot.start, notBefore)
            guard earliest.timeIntervalSince1970.isFinite else { return nil }
            let roundedSeconds = ceil(earliest.timeIntervalSince1970 / 60) * 60
            guard roundedSeconds.isFinite, roundedSeconds < Double(Int.max),
                  roundedSeconds > Double(Int.min) else { return nil }
            let start = Date(timeIntervalSince1970: roundedSeconds)
            let end = start.addingTimeInterval(duration)
            guard slot.end > start, end <= slot.end else { return nil }
            let id = "\(plan.id)-later-\(Int(start.timeIntervalSince1970))-\(plan.minutes)"
            guard seen.insert(id).inserted else { return nil }
            return RescheduleProposal(id: id, planID: plan.id, title: plan.title, start: start, end: end)
        }.prefix(min(limit, 3)).map { $0 }
    }

    public static func validate(
        _ proposal: RescheduleProposal,
        now: Date,
        busyIntervals: [BusyInterval],
        paddingMinutes: Int = 15,
        safetyFlags: [SafetyFlag] = []
    ) -> RescheduleValidation {
        guard !SafetyGate.evaluate(safetyFlags).blocksPerformanceRecommendations else {
            return .safetyBlocked
        }
        guard proposal.start.timeIntervalSinceReferenceDate.isFinite,
              proposal.end.timeIntervalSinceReferenceDate.isFinite,
              proposal.end > proposal.start,
              !proposal.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .invalidTime
        }
        guard proposal.start >= now else { return .inThePast }
        let padding = Double(max(0, paddingMinutes)) * 60
        let conflicts = busyIntervals.contains { busy in
            guard busy.end > busy.start else { return false }
            return proposal.start < busy.end.addingTimeInterval(padding)
                && proposal.end > busy.start.addingTimeInterval(-padding)
        }
        return conflicts ? .calendarConflict : .valid
    }
}
