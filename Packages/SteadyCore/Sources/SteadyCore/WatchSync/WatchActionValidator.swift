import Foundation

public enum WatchActionValidator {
    /// Call in the phone's serial persistence boundary immediately before a local
    /// mutation. Never prune current-day receipts: stale snapshots prevent older
    /// actions from becoming newly applicable after older receipts are removed.
    public static func evaluate(
        _ action: WatchAction, snapshot: WatchSnapshot, current: WatchCurrentContext,
        receipts: [WatchActionReceipt], clock: any Clock,
        calendar: Calendar = SteadyCalendar.singapore()
    ) -> WatchActionDecision {
        let matching = receipts.filter { $0.action.id == action.id }
        if !matching.isEmpty {
            guard matching.allSatisfy({ $0.action == action }),
                  let first = matching.first, matching.allSatisfy({ $0 == first }),
                  WatchPayloadRules.identifier(first.id), WatchPayloadRules.finite(first.processedAt),
                  (try? WatchWireCodec.encode(first)) != nil else {
                return .reject(.conflictingReplay)
            }
            return .replay(first)
        }
        guard action.schemaVersion == 1 else { return .reject(.unsupportedVersion) }
        guard WatchPayloadRules.identifier(action.id), WatchPayloadRules.identifier(action.snapshotID) else {
            return .reject(.invalidIdentifier)
        }
        guard (try? WatchWireCodec.encode(action)) != nil else { return .reject(.malformedPayload) }
        if let issue = WatchSnapshotValidator.issue(in: snapshot, clock: clock, calendar: calendar) {
            return .reject(issue)
        }
        let now = clock.now
        guard [action.day, action.createdAt, current.day].allSatisfy(WatchPayloadRules.finite) else {
            return .reject(.malformedPayload)
        }
        guard calendar.isDate(action.day, inSameDayAs: now),
              calendar.isDate(current.day, inSameDayAs: now),
              calendar.isDate(action.createdAt, inSameDayAs: now),
              action.day == calendar.startOfDay(for: action.day) else { return .reject(.staleDay) }
        guard action.createdAt <= now else { return .reject(.futureTimestamp) }
        guard action.createdAt >= snapshot.createdAt, action.createdAt < snapshot.expiresAt else {
            return .reject(.expiredSnapshot)
        }
        guard action.profileID == snapshot.profileID, action.profileID == current.profileID else {
            return .reject(.profileMismatch)
        }
        guard action.useSampleData == snapshot.useSampleData, action.useSampleData == current.useSampleData else {
            return .reject(.sampleMismatch)
        }
        guard action.snapshotID == snapshot.id, action.snapshotID == current.snapshotID,
              action.snapshotRevision == snapshot.revision,
              action.snapshotRevision == current.snapshotRevision else { return .reject(.staleSnapshot) }
        guard snapshot.lowDataMode == current.lowDataMode,
              snapshot.safetyBlocked == current.safetyBlocked else { return .reject(.contextChanged) }
        // A handoff is just a route to a dated existing record, never a food choice.
        if snapshot.safetyBlocked || current.safetyBlocked {
            if case .savedMealHandoff = action.kind {} else { return .reject(.safetyBlocked) }
        }
        switch action.kind {
        case .chooseAlternative(let id):
            guard WatchPayloadRules.identifier(id), snapshot.alternatives.contains(where: { $0.id == id }),
                  current.alternativeOptionIDs.contains(id) else { return .reject(.unknownOption) }
        case .foundationDone(let kind, let id):
            guard WatchPayloadRules.identifier(id), snapshot.foundation?.kind == kind,
                  snapshot.foundation?.optionID == id, current.foundationKind == kind,
                  current.foundationOptionID == id else { return .reject(.unknownOption) }
        case .savedMealHandoff(let id):
            guard WatchPayloadRules.identifier(id), snapshot.savedMeals.contains(where: { $0.id == id }),
                  current.savedCorrectionIDs.contains(id) else { return .reject(.unknownOption) }
        case .logMovement(let kind, let minutes):
            guard WatchMovementKind.allowedMinutes.contains(minutes),
                  snapshot.movementKinds.contains(kind), current.movementKinds.contains(kind) else {
                return .reject(.invalidMovement)
            }
        }
        return .apply
    }
}
