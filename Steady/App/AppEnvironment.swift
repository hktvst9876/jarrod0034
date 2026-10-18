import Foundation
import Observation
import SteadyCore

@MainActor
@Observable
final class AppEnvironment {
    let advisor = AdvisorStore()
    let dataLifecycle = DataLifecycle()
    @ObservationIgnored private let clock: any SteadyCore.Clock
    @ObservationIgnored private let liveHealth: any HealthDataProviding
    @ObservationIgnored private let sampleHealth: any HealthDataProviding
    @ObservationIgnored private let liveCalendar: any CalendarProviding
    @ObservationIgnored private let sampleCalendar: any CalendarProviding
    @ObservationIgnored private let liveNotifications: any NotificationProviding
    @ObservationIgnored private var sampleNotifications: any NotificationProviding
    @ObservationIgnored private let liveFoodDiscovery: any FoodDiscoveryProviding
    @ObservationIgnored private let sampleFoodDiscovery: any FoodDiscoveryProviding
    @ObservationIgnored private let liveFoodLocation: any FoodLocationProviding
    @ObservationIgnored private let sampleFoodLocation: any FoodLocationProviding
    @ObservationIgnored private let liveCompanion: any CompanionTransport
    @ObservationIgnored private let sampleCompanion: any CompanionTransport

    init(
        clock: any SteadyCore.Clock = SystemClock(),
        liveHealth: any HealthDataProviding = HealthKitProvider(),
        liveCalendar: any CalendarProviding = EventKitProvider(),
        liveNotifications: any NotificationProviding = LocalNotificationProvider(),
        liveFoodDiscovery: any FoodDiscoveryProviding = MapKitFoodDiscoveryProvider(),
        liveFoodLocation: (any FoodLocationProviding)? = nil,
        liveCompanion: (any CompanionTransport)? = nil
    ) {
        self.clock = clock
        self.liveHealth = liveHealth
        self.sampleHealth = SampleHealthProvider(now: clock.now)
        self.liveCalendar = liveCalendar
        self.sampleCalendar = SampleCalendarProvider(clock: clock)
        self.liveNotifications = liveNotifications
        self.sampleNotifications = SampleNotificationProvider()
        self.liveFoodDiscovery = liveFoodDiscovery
        self.sampleFoodDiscovery = SampleFoodDiscoveryProvider()
        self.liveFoodLocation = liveFoodLocation ?? ApproximateFoodLocationProvider(clock: clock)
        self.sampleFoodLocation = SampleFoodLocationProvider()
        self.liveCompanion = liveCompanion ?? WCCompanionTransport()
        self.sampleCompanion = SampleCompanionTransport()
    }

    var now: Date { clock.now }
    var calendar: Calendar { SteadyCalendar.singapore() }

    func health(useSampleData: Bool) -> any HealthDataProviding {
        useSampleData ? sampleHealth : liveHealth
    }

    func calendar(useSampleData: Bool) -> any CalendarProviding {
        useSampleData ? sampleCalendar : liveCalendar
    }

    func notifications(useSampleData: Bool) -> any NotificationProviding {
        useSampleData ? sampleNotifications : liveNotifications
    }

    func foodDiscovery(useSampleData: Bool) -> any FoodDiscoveryProviding {
        useSampleData ? sampleFoodDiscovery : liveFoodDiscovery
    }

    func foodLocation(useSampleData: Bool) -> any FoodLocationProviding {
        useSampleData ? sampleFoodLocation : liveFoodLocation
    }

    func companion(useSampleData: Bool) -> any CompanionTransport {
        useSampleData ? sampleCompanion : liveCompanion
    }

    func clearLocalServicesForDeletion() async {
        await liveNotifications.cancelAll()
        await sampleNotifications.cancelAll()
        sampleNotifications = SampleNotificationProvider()
        try? sampleCompanion.resetLocalQueues()
        await liveCalendar.resetLocalState()
        await sampleCalendar.resetLocalState()
        FoundationNotificationInbox.shared.clear()
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

