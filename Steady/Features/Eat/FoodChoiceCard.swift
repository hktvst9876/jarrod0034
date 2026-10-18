import SteadyCore
import SwiftUI

struct FoodChoiceCard: View {
    let assessment: FoodAssessment
    let lowDataMode: Bool
    let requiresCheck: Bool
    let onRemember: () -> Void
    @State private var why: WhyItem?

    private var candidate: FoodCandidate { assessment.candidate }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(candidate.dishName).font(.headline)
            if let place = candidate.place {
                Text(place.name == candidate.dishName ? place.area : "\(place.name) - \(place.area)")
                    .font(.subheadline)
                Button("\(candidate.ingredients?.source.kind == .userSaved ? "Your saved place" : "Apple Maps discovery") / \(FoodDisplay.date(place.checkedAt)) / low confidence - Why") {
                    why = WhyItem(title: "Place identity only", explanation: "\(candidate.ingredients?.source.kind == .userSaved ? "You supplied this place" : "Apple Maps supplied this place") on \(FoodDisplay.date(place.checkedAt)). This is not evidence of a menu item, opening status, ingredients, price, or nutrition. Confidence applies only to the stated source; verify the right outlet directly.")
                }.font(.caption)
            }
            if requiresCheck {
                Label("Check directly before choosing", systemImage: "questionmark.shield")
                    .font(.subheadline.bold())
                Text("Not a primary recommendation. Unknown ingredients are not an allergy or dietary guarantee.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            ForEach(assessment.reasons, id: \.self) { Text($0).font(.footnote).foregroundStyle(.secondary) }
            price
            ingredients
            menu
            nutrition
            Text("Opening hours: not known. Availability today: not known.")
                .font(.footnote).foregroundStyle(.secondary)
            Button("Remember an observation") { onRemember() }.buttonStyle(.bordered)
        }
        .steadyCard()
        .sheet(item: $why) { WhySheet(title: $0.title, explanation: $0.explanation) }
    }

    @ViewBuilder private var price: some View {
        if let evidence = assessment.approvedPrice {
            Button("\(FoodDisplay.price(evidence.value.amountSGD)) / \(evidence.value.portion) - Why") {
                showEvidence(evidence, title: "Per-item price", basis: "This is a sourced or prior-visit amount for the stated portion, not a current bill or a spending total.")
            }.font(.subheadline)
            caption(evidence)
        } else {
            Text("Price not known. A saved amount may be stale or unverified.").font(.footnote).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var ingredients: some View {
        if let evidence = candidate.ingredients {
            Text(evidence.value.listedIngredients.isEmpty ? "Ingredient list unavailable." : "Ingredient notes: \(evidence.value.listedIngredients.joined(separator: ", "))")
                .font(.footnote)
            if !evidence.value.contains.isEmpty || !evidence.value.otherKnownAllergens.isEmpty {
                Text("Known allergens noted: \((evidence.value.contains.map(FoodDisplay.title) + evidence.value.otherKnownAllergens).joined(separator: ", "))")
                    .font(.footnote)
            }
            Button("Ingredient source and uncertainty - Why") {
                showEvidence(evidence, title: "Ingredient evidence", basis: "Saved notes remain incomplete and may be stale. Do not infer absence from an unlisted allergen. Ask about ingredients, substitutions, preparation, and cross-contact directly.")
            }.font(.caption)
            caption(evidence)
        } else {
            Text("Ingredients not known. Check allergens, dietary rules, and cross-contact directly with the place.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var menu: some View {
        if let evidence = assessment.approvedMenu {
            Link("Identity-matched official menu", destination: evidence.value)
            Button("Menu source - Why") {
                showEvidence(evidence, title: "Official menu link", basis: "This link is attached only when the source identifies the same outlet. A menu link alone does not verify current availability, prices, or ingredients.")
            }.font(.caption)
            caption(evidence)
        } else {
            Text("Official menu not verified. A directory website is not a verified menu.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var nutrition: some View {
        if lowDataMode {
            Text("Nutrition details hidden in low-data mode.").font(.footnote).foregroundStyle(.secondary)
        } else if let evidence = assessment.approvedNutrition {
            Button("\(evidence.value.energyKcalLower.formatted())-\(evidence.value.energyKcalUpper.formatted()) kcal - Why") {
                showEvidence(evidence, title: "Nutrition range", basis: evidence.value.portionAssumptions)
            }.font(.subheadline)
            if let lower = evidence.value.proteinGramsLower, let upper = evidence.value.proteinGramsUpper {
                Button("\(lower.formatted())-\(upper.formatted()) g protein - Why") {
                    showEvidence(evidence, title: "Protein range", basis: evidence.value.portionAssumptions)
                }.font(.subheadline)
            }
            Text("Portion assumptions: \(evidence.value.portionAssumptions)").font(.footnote)
            caption(evidence)
            if let url = evidence.source.url { Link("Cited nutrition source: \(evidence.source.title)", destination: url).font(.footnote) }
        } else {
            Text("Nutrition estimate unavailable. No defensible cited dish-and-serving match is attached.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private func caption<Value: Codable & Equatable & Sendable>(_ evidence: FoodEvidence<Value>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Button("\(evidence.source.title) / \(FoodDisplay.date(evidence.checkedAt)) / \(evidence.confidence.rawValue) confidence - Why") {
                showEvidence(evidence, title: "Source, date, and confidence", basis: "Check time is the evidence date, not a promise that the fact is unchanged today.")
            }.font(.caption).foregroundStyle(.secondary)
            if !evidence.uncertainty.isEmpty {
                Text(evidence.uncertainty.joined(separator: " ")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func showEvidence<Value: Codable & Equatable & Sendable>(_ evidence: FoodEvidence<Value>, title: String, basis: String) {
        let uncertainty = evidence.uncertainty.isEmpty ? "No extra uncertainty supplied; current conditions still need checking." : evidence.uncertainty.joined(separator: " ")
        why = WhyItem(title: title, explanation: "\(basis) Source: \(evidence.source.title). Checked: \(FoodDisplay.date(evidence.checkedAt)). Confidence: \(evidence.confidence.rawValue). \(uncertainty)")
    }
}
