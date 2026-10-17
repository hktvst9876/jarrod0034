import SwiftData
import SwiftUI

@main
struct SteadyApp: App {
    @State private var environment = AppEnvironment()
    private let modelContainerResult: Result<ModelContainer, Error>

    init() {
        modelContainerResult = Result { try ModelContainer(for: ProfileRecord.self, PlanRecord.self, ChoiceRecord.self) }
    }

    var body: some Scene {
        WindowGroup {
            switch modelContainerResult {
            case .success(let modelContainer):
                AppLaunchView()
                    .environment(environment)
                    .environment(\.calendar, environment.calendar)
                    .environment(\.timeZone, environment.calendar.timeZone)
                    .modelContainer(modelContainer)
            case .failure:
                DataStoreErrorView()
            }
        }
    }
}

private struct DataStoreErrorView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Steady could not open its data", systemImage: "externaldrive.badge.exclamationmark")
        } description: {
            Text("Your existing data has not been erased. Close Steady and try again, or check device storage.")
        }
    }
}


