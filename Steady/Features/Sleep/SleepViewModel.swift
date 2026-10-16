import Observation
import SteadyCore

@MainActor
@Observable
final class SleepViewModel {
    var sleep: SleepContext = .missing
    var isLoading = false

    func load(profile record: ProfileRecord, environment: AppEnvironment, useSampleData: Bool) async {
        guard let profile = record.domainProfile() else { return }
        isLoading = true
        let loader = PhaseOneContextLoader(
            health: environment.health(useSampleData: useSampleData),
            calendarProvider: environment.calendar(useSampleData: useSampleData),
            calendar: environment.calendar
        )
        let snapshot = await loader.load(at: environment.now, profile: profile)
        sleep = snapshot.sleep
        isLoading = false
    }
}

