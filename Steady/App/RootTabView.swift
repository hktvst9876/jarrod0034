import SwiftUI

struct RootTabView: View {
    let profile: ProfileRecord
    @State private var todayModel = TodayViewModel()
    @State private var planStore = PlanStore()

    var body: some View {
        TabView {
            TodayView(profile: profile, model: todayModel)
                .tabItem { Label("Today", systemImage: "sun.max") }

            MoveView(profile: profile, todayModel: todayModel)
                .tabItem { Label("Move", systemImage: "figure.walk") }

            SleepView(profile: profile)
                .tabItem { Label("Sleep", systemImage: "moon.stars") }

            EatView()
                .tabItem { Label("Eat", systemImage: "fork.knife") }

            WeekView()
                .tabItem { Label("Week", systemImage: "calendar") }
        }
        .tint(.teal)
        .environment(planStore)
    }
}

