import SwiftUI

struct EatView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Food help, when you ask",
                systemImage: "fork.knife.circle",
                description: Text("Sourced meal suggestions arrive in a later phase.")
            )
            .navigationTitle("Eat")
        }
    }
}

