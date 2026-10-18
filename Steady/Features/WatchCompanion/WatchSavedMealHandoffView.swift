import SwiftUI

struct WatchSavedMealHandoffView: View {
    let route: WatchMealRoute
    let onDone: () -> Void
    @State private var why: WhyItem?

    var body: some View {
        NavigationStack {
            Form {
                Section("Saved observation from Watch") {
                    Text(route.title).font(.headline)
                    Button("Saved from prior visit: \(FoodDisplay.date(route.observedAt)) — Why") {
                        why = WhyItem(title: "Prior-visit date", explanation: "This is the date recorded for that observation, not a check of today's menu, ingredients, price, or cross-contact handling.")
                    }
                    Text("This is a handoff to a dated record, not a meal recommendation or a claim that you ate it. Check current ingredients and allergy suitability directly. Nothing was corrected or remembered by this action.")
                    Text("Your saved observations and the separate Remember review remain available in Eat.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Button("Done", action: onDone)
            }
            .navigationTitle("Eat handoff")
        }
        .sheet(item: $why) { WhySheet(title: $0.title, explanation: $0.explanation) }
    }
}
