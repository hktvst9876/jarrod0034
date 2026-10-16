import Foundation
import Observation
import SteadyCore

@MainActor
@Observable
final class AppEnvironment {
    @ObservationIgnored private let clock: any SteadyCore.Clock
    @ObservationIgnored private let liveHealth: any HealthDataProviding
    @ObservationIgnored private let sampleHealth: any HealthDataProviding
    @ObservationIgnored private let liveCalendar: any CalendarProviding
    @ObservationIgnored private let sampleCalendar: any CalendarProviding

    init(
        clock: any SteadyCore.Clock = SystemClock(),
        liveHealth: any HealthDataProviding = HealthKitProvider(),
        liveCalendar: any CalendarProviding = EventKitProvider()
    ) {
        self.clock = clock
        self.liveHealth = liveHealth
        self.sampleHealth = SampleHealthProvider(now: clock.now)
        self.liveCalendar = liveCalendar
        self.sampleCalendar = SampleCalendarProvider(now: clock.now)
    }

    var now: Date { clock.now }
    var calendar: Calendar { SteadyCalendar.singapore() }

    func health(useSampleData: Bool) -> any HealthDataProviding {
        useSampleData ? sampleHealth : liveHealth
    }

    func calendar(useSampleData: Bool) -> any CalendarProviding {
        useSampleData ? sampleCalendar : liveCalendar
    }

    func requestHealthAccessMessage() async -> String {
        do {
            _ = try await liveHealth.requestReadAccess()
            return "Request completed. Steady will use only the Health items you chose; Apple keeps read choices private."
        } catch {
            return error.localizedDescription
        }
    }

    func requestCalendarAccessMessage() async -> String {
        do {
            let state = try await liveCalendar.requestFullAccess()
            switch state {
            case .fullAccess:
                return "Calendar access is ready. Event details stay in Calendar."
            case .denied, .notDetermined:
                return "Calendar access is off. You can enter your free time manually."
            }
        } catch {
            return error.localizedDescription
        }
    }
}

