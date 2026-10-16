import SteadyCore
import SwiftUI

struct MorningCheckInSheet: View {
    let choose: (CheckIn) -> Void

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(CheckIn.allCases.filter { $0 != .skipped }, id: \.rawValue) { option in
                        Button(option.title) { choose(option) }
                    }
                } header: {
                    Text("What feels difficult today?")
                } footer: {
                    Text("One tap is enough. This changes today's suggestion, not your profile.")
                }
                Button("Skip for today") { choose(.skipped) }
            }
            .navigationTitle("Morning check-in")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
    }
}

