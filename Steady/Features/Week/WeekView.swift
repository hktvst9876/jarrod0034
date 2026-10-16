import SwiftUI

struct WeekView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "A calm look back",
                systemImage: "calendar.badge.clock",
                description: Text("Weekly patterns and one small experiment arrive later.")
            )
            .navigationTitle("Week")
        }
    }
}

