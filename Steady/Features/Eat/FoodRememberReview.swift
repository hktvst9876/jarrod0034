import SteadyCore
import SwiftUI

struct FoodRememberReview: View {
    let proposal: FoodCorrectionProposal
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @State private var why: WhyItem?

    private var draft: FoodCorrectionDraft { proposal.draft }
    private var knownAllergensText: String {
        let labels = draft.knownAllergens.map(FoodDisplay.title) + draft.otherKnownAllergens
        return labels.isEmpty ? "not recorded, not proof of absence" : labels.joined(separator: ", ")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Review before remembering") {
                    Text(draft.dishName).font(.headline)
                    if let place = draft.place {
                        Text("Place you checked: \(place.name)")
                        Text("Area: \(place.area)")
                    } else { Text("No place or area will be saved.") }
                    Text("Meal: \(draft.mealTypes.map(FoodDisplay.title).joined(separator: ", "))")
                    Text("Preparation needed: \(FoodDisplay.title(draft.requiredKitchen))")
                    Button("Observed \(FoodDisplay.date(draft.observedAt)) - Why") {
                        why = WhyItem(title: "Date of the observation", explanation: "This is when you checked the item. Confirming today does not refresh this date or establish current availability, ingredients, or price.")
                    }
                    Button("Portion: \(draft.portion) - Why") {
                        why = WhyItem(title: "Saved portion", explanation: "This is your dish or portion description, saved even without a price. It is not a measured serving or a nutrition match.")
                    }
                    if let price = draft.priceSGD {
                        Button("\(FoodDisplay.price(price)) / \(draft.portion) - Why") {
                            why = WhyItem(title: "Prior-visit price", explanation: "This is your observed SGD amount for the stated item or portion. It may change. It can affect later per-item ordering only after this confirmation, and never becomes a spending total.")
                        }
                    } else { Text("Price not known.") }
                    Text(draft.ingredientNotes.isEmpty ? "Ingredient list unavailable." : "Ingredient notes: \(draft.ingredientNotes.joined(separator: ", "))")
                    Text("Known allergens present: \(knownAllergensText)")
                    Text("Nutrition, menu link, opening hours, and current availability will not be saved or inferred.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                Section("What confirmation does") {
                    Text("Source: your prior-visit observation. Confidence: low. Ingredient completeness and cross-contact remain unknown, so this cannot become a primary recommendation. Check directly with the place before choosing.")
                    Text(proposal.isSample ? "This saves to this profile's sample records only." : "This saves to this profile on this device only.")
                    Text("Only the reviewed dish, place label/area, meal/preparation needs, observation date, ingredient notes, known allergens, and optional per-item price are remembered. Search coordinates and directory websites are not retained.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Confirm - Remember this", action: onConfirm)
                        .buttonStyle(.borderedProminent)
                    Button("Cancel - do not remember", role: .cancel, action: onCancel)
                }
            }
            .navigationTitle("Remember this?")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel", action: onCancel) } }
        }
        .sheet(item: $why) { WhySheet(title: $0.title, explanation: $0.explanation) }
    }
}
