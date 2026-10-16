import SwiftUI

struct WhySheet: View {
    let title: String
    let explanation: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Label(title, systemImage: "info.circle")
                    .font(.title2.bold())
                Text(explanation)
                    .font(.body)
                Spacer()
            }
            .padding()
            .navigationTitle("Why")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
