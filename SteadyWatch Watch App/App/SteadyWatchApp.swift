import SwiftUI

@main
struct SteadyWatchApp: App {
    @State private var model = WatchCompanionModel()

    var body: some Scene {
        WindowGroup {
            WatchCompanionView(model: model)
        }
        .backgroundTask(.watchConnectivity) { await model.receiveInBackground() }
    }
}

