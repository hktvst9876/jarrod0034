import SwiftUI

struct WatchPlaceholderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "leaf.fill")
                .font(.title)
                .foregroundStyle(.teal)
            Text("Steady")
                .font(.headline)
            Text("Your plan will appear here.")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
