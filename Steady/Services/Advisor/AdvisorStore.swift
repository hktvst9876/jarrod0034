import Foundation
import Observation

/// Preferences contain only a switch. Activity is memory-only and never contains request/response data.
@MainActor
@Observable
final class AdvisorStore {
    enum Activity: Sendable { case template, onDevice, fallback, timedOut, discarded }

    private(set) var revision = UUID()
    private(set) var activity: [Activity] = []
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var activeKey: String?

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func activate(profileID: UUID, sample: Bool) {
        let key = preferenceKey(profileID: profileID, sample: sample)
        guard activeKey != key else { return }
        activeKey = key
        clearActivity()
    }

    func isEnabled(profileID: UUID, sample: Bool) -> Bool {
        _ = revision
        return defaults.bool(forKey: preferenceKey(profileID: profileID, sample: sample))
    }

    func setEnabled(_ value: Bool, profileID: UUID, sample: Bool) {
        guard !DataDeletionGate.shared.isBlocked else { return }
        defaults.set(value, forKey: preferenceKey(profileID: profileID, sample: sample))
        revision = UUID()
    }

    func clearActivity() {
        activity = []
        revision = UUID()
    }

    func resetForDeletion() {
        activeKey = nil
        clearActivity()
    }

    func record(_ event: Activity, revision expected: UUID) {
        guard revision == expected else { return }
        activity.append(event)
        if activity.count > 20 { activity.removeFirst(activity.count - 20) }
    }

    private func preferenceKey(profileID: UUID, sample: Bool) -> String {
        "steady.advisor.ordering.\(profileID.uuidString).\(sample)"
    }
}
