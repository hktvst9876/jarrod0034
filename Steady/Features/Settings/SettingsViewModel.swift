import Observation

@MainActor
@Observable
final class SettingsViewModel {
    var healthStatus = "Checking…"
    var calendarStatus = "Checking…"
    var isRequesting = false

    func refresh(using environment: AppEnvironment) async {
        let health = await environment.health(useSampleData: false).accessState()
        let calendar = await environment.calendar(useSampleData: false).accessState()

        healthStatus = switch health {
        case .notAvailable: "Apple Health is not available on this device."
        case .notRequested: "Health access has not been requested in this session."
        case .requestCompleted: "Health choices were requested. Available samples are used when readable."
        }
        calendarStatus = switch calendar {
        case .fullAccess: "Calendar access is ready."
        case .denied: "Calendar access is off. Manual availability still works."
        case .notDetermined: "Calendar access has not been requested."
        }
    }

    func requestHealth(using environment: AppEnvironment) async {
        isRequesting = true
        healthStatus = await environment.requestHealthAccessMessage()
        isRequesting = false
    }

    func requestCalendar(using environment: AppEnvironment) async {
        isRequesting = true
        calendarStatus = await environment.requestCalendarAccessMessage()
        isRequesting = false
    }
}

