import Foundation
import Observation
import SteadyCore

@MainActor
@Observable
final class SleepViewModel {
    var sleep: SleepContext = .missing
    var isLoading = false
    private var loadRequestID = UUID()
    private var loadedSampleMode: Bool?
    private var loadedProfile: Profile?
    private var loadedDay: Date?
    private var loadedPrivacyRevision: Int?

    func invalidate() {
        loadRequestID = UUID()
        sleep = .missing
        isLoading = false
        loadedSampleMode = nil; loadedProfile = nil; loadedDay = nil; loadedPrivacyRevision = nil
    }

    func load(profile record: ProfileRecord, environment: AppEnvironment, useSampleData: Bool,
              requestIsCurrent: () -> Bool = { true }) async {
        let privacyRevision = DataDeletionGate.shared.revision
        guard !DataDeletionGate.shared.isBlocked, let profile = record.domainProfile() else {
            invalidate()
            return
        }
        let requestID = UUID()
        loadRequestID = requestID
        let now = environment.now
        let day = environment.calendar.startOfDay(for: now)
        // Never leave real data visible while a new sample/profile/day is loading.
        if loadedSampleMode != useSampleData || loadedProfile != profile || loadedDay != day
            || loadedPrivacyRevision != privacyRevision { sleep = .missing }
        loadedSampleMode = useSampleData; loadedProfile = profile; loadedDay = day
        loadedPrivacyRevision = privacyRevision
        isLoading = true
        defer { if loadRequestID == requestID { isLoading = false } }
        let loader = PhaseOneContextLoader(
            health: environment.health(useSampleData: useSampleData),
            calendarProvider: environment.calendar(useSampleData: useSampleData),
            calendar: environment.calendar
        )
        let snapshot = await loader.load(at: now, profile: profile)
        guard !DataDeletionGate.shared.isBlocked, privacyRevision == DataDeletionGate.shared.revision,
              loadRequestID == requestID, !Task.isCancelled, requestIsCurrent(),
              record.domainProfile() == profile,
              environment.calendar.startOfDay(for: environment.now) == day else { return }
        sleep = snapshot.sleep
    }
}

