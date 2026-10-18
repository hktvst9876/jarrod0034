import SteadyCore
import SwiftUI

/// This sheet is a draft. Its Remember button only opens a separate confirmation.
struct FoodCorrectionEditor: View {
    @Environment(\.dismiss) private var dismiss
    let source: FoodEditorSource
    let onRemember: (FoodCorrectionDraft, EatActionSource) -> Bool
    @State private var dishName: String
    @State private var venueName: String
    @State private var area: String
    @State private var observedAt: Date
    @State private var priceText: String
    @State private var portion: String
    @State private var ingredientsText: String
    @State private var allergens: [FoodAllergen]
    @State private var otherAllergens: String
    @State private var requiredKitchen: FoodKitchenAccess
    @State private var why: WhyItem?
    @State private var reviewError: String?

    init(source: FoodEditorSource, onRemember: @escaping (FoodCorrectionDraft, EatActionSource) -> Bool) {
        self.source = source
        self.onRemember = onRemember
        let saved = source.candidate?.ingredients?.source.kind == .userSaved
        _dishName = State(initialValue: saved ? source.candidate?.dishName ?? "" : "")
        _venueName = State(initialValue: source.candidate?.place?.name ?? "")
        _area = State(initialValue: source.candidate?.place?.area ?? source.actionSource.request.area)
        _observedAt = State(initialValue: source.observedAt)
        _priceText = State(initialValue: source.candidate?.price.map { String($0.value.amountSGD) } ?? "")
        _portion = State(initialValue: source.candidate?.price?.value.portion ?? "per dish")
        _ingredientsText = State(initialValue: source.candidate?.ingredients?.value.listedIngredients.joined(separator: ", ") ?? "")
        _allergens = State(initialValue: source.candidate?.ingredients?.value.contains ?? [])
        _otherAllergens = State(initialValue: source.candidate?.ingredients?.value.otherKnownAllergens.joined(separator: ", ") ?? "")
        _requiredKitchen = State(initialValue: source.candidate?.requiredKitchen ?? .none)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("What you observed") {
                    TextField("Dish name", text: $dishName)
                    TextField("Place name (optional)", text: $venueName)
                    TextField("Area or campus", text: $area)
                    Text("To retain an area, give the place a name. For home preparation, enter your own label such as Home; Steady does not invent a place.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Picker("Preparation needed", selection: $requiredKitchen) {
                        ForEach(FoodKitchenAccess.allCases, id: \.rawValue) { kitchen in
                            Text(FoodDisplay.title(kitchen)).tag(kitchen)
                        }
                    }
                    DatePicker("Observed on", selection: $observedAt)
                    Button("Why this date matters") {
                        why = WhyItem(title: "Observation date", explanation: "The date is when you checked the item, not when you saved it. Keep a prior visit's date unless you checked again. It never guarantees today's ingredients or price.")
                    }
                    Text("Enter the dish you actually checked. A place search did not establish its menu or opening hours.")
                }
                Section("Price, if you checked it") {
                    TextField("Observed SGD price (optional)", text: $priceText).keyboardType(.decimalPad)
                    TextField("Portion or item", text: $portion)
                    Button("Why this price is not current") {
                        why = WhyItem(title: "Per-item observation", explanation: "This optional SGD amount is a prior-visit price for the stated portion. It may change and is not a bill, spending total, or saving. Leave it blank when unknown.")
                    }
                    if !priceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && price == nil {
                        Text("Use a finite nonnegative SGD amount, or leave price blank.").foregroundStyle(.red)
                    }
                }
                Section("Ingredients you know about") {
                    TextField("Ingredient notes, separated by commas", text: $ingredientsText, axis: .vertical)
                    DisclosureGroup("Known allergens present") {
                        ForEach(FoodAllergen.allCases, id: \.rawValue) { allergen in
                            Toggle(FoodDisplay.title(allergen), isOn: allergenBinding(allergen))
                        }
                        TextField("Other known allergens present", text: $otherAllergens, axis: .vertical)
                    }
                    Text("These are incomplete prior-visit notes. Not selecting an allergen does not mean it is absent. Cross-contact, substitutions, dietary rules, and today's ingredients must still be checked directly with the place.")
                }
                Section {
                    Button("Remember this - review first") {
                        if !onRemember(draft(), source.actionSource) {
                            reviewError = "Check the dish, nonfuture observation date, price, and notes, or reopen the draft if its context changed. Nothing was saved."
                        }
                    }.disabled(!valid)
                    if let reviewError { Text(reviewError).foregroundStyle(.red) }
                    Text("Nothing is saved until you review the observation and confirm Remember this on the next screen.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Food observation")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }
        .sheet(item: $why) { WhySheet(title: $0.title, explanation: $0.explanation) }
    }

    private var price: Double? {
        let value = priceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let amount = Double(value), amount.isFinite, amount >= 0 else { return nil }
        return amount
    }

    private var valid: Bool {
        !dishName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (area.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !venueName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            && (venueName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !area.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            && (priceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || price != nil)
            && (price == nil || !portion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    }

    private func draft() -> FoodCorrectionDraft {
        let saved = source.candidate?.ingredients?.source.kind == .userSaved
        let candidateID = saved ? source.candidate?.id ?? "saved:\(source.id.uuidString)" : "saved:\(source.id.uuidString)"
        let venue = venueName.trimmingCharacters(in: .whitespacesAndNewlines)
        // Never persist search coordinates, directory URLs, or coordinate-bearing discovery IDs.
        let place = venue.isEmpty ? nil : FoodPlace(
            id: saved ? source.candidate?.place?.id ?? "remembered-place:\(source.id.uuidString)" : "remembered-place:\(source.id.uuidString)",
            name: venue, area: area, checkedAt: observedAt)
        return FoodCorrectionDraft(candidateID: candidateID, dishName: dishName, place: place,
            mealTypes: [source.actionSource.request.mealType], requiredKitchen: requiredKitchen, observedAt: observedAt,
            priceSGD: price, portion: portion, ingredientNotes: EatRequestInputs.notes(ingredientsText),
            knownAllergens: allergens, otherKnownAllergens: EatRequestInputs.notes(otherAllergens))
    }

    private func allergenBinding(_ allergen: FoodAllergen) -> Binding<Bool> {
        Binding(get: { allergens.contains(allergen) }, set: { selected in
            allergens.removeAll { $0 == allergen }
            if selected { allergens.append(allergen) }
        })
    }
}
