import SwiftUI

struct MoveView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Move with room to adapt",
                systemImage: "figure.strengthtraining.traditional",
                description: Text("Sessions and shorter alternatives arrive in Phase 2.")
            )
            .navigationTitle("Move")
        }
    }
}

