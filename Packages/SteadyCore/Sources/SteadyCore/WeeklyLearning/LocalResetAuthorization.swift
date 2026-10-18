import Foundation

public enum LocalResetDecision: String, Codable, Equatable, Sendable {
    case begin, resume, refuse
}

/// A recovery callback is authority only for a currently pending confirmed reset.
/// It cannot become a new destructive confirmation after that reset has finished.
public enum LocalResetAuthorization {
    public static func evaluate(expectedRevision: Int?, currentRevision: Int,
                                isBlocked: Bool, hasPendingDeletion: Bool) -> LocalResetDecision {
        guard currentRevision >= 0 else { return .refuse }
        if let expectedRevision {
            guard expectedRevision >= 0, expectedRevision == currentRevision,
                  !isBlocked, !hasPendingDeletion else { return .refuse }
            return .begin
        }
        return isBlocked && hasPendingDeletion ? .resume : .refuse
    }
}
