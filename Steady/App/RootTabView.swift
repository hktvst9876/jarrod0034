import SwiftUI

struct RootTabView: View {
    let profile: ProfileRecord

    var body: some View {
        TabView {
            TodayView(profile: profile)
                .tabItem { Label("Today", systemImage: "sun.max") }

            MoveView()
                .tabItem { Label("Move", systemImage: "figure.walk") }

            SleepView(profile: profile)
                .tabItem { Label("Sleep", systemImage: "moon.stars") }

            EatView()
                .tabItem { Label("Eat", systemImage: "fork.knife") }

            WeekView()
                .tabItem { Label("Week", systemImage: "calendar") }
        }
        .tint(.teal)
    }
}

