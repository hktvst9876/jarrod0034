import Foundation
@testable import SteadyCore

func foodDate() -> Date { testDate(2026, 10, 18, 12, 0) }

func foodPlace(id: String = "venue", area: String = "Campus") -> FoodPlace {
    FoodPlace(id: id, name: "Test venue", area: area,
              websiteURL: URL(string: "https://venue.example"),
              coordinate: FoodCoordinate(latitude: 1.3, longitude: 103.8), checkedAt: foodDate())
}

func foodOfficialSource(placeID: String = "venue", identityMatched: Bool = true,
                        url: String = "https://venue.example/menu") -> FoodEvidenceSource {
    FoodEvidenceSource(kind: .officialMenu, title: "Test venue menu", url: URL(string: url),
                       placeID: placeID, identityMatched: identityMatched)
}

func foodIngredients(contains: [FoodAllergen] = [], mayContain: [FoodAllergen] = [],
                     listed: [String] = ["rice", "carrot"], complete: Bool = true,
                     coverage: [FoodAllergen] = FoodAllergen.allCases,
                     otherCoverage: [String] = [], dietary: [FoodDietaryRule] = [],
                     otherDietary: [String] = [], source: FoodEvidenceSource? = nil,
                     checkedAt: Date? = nil, confidence: FoodConfidence = .high,
                     uncertainty: [String] = []) -> FoodEvidence<FoodIngredients> {
    FoodEvidence(value: FoodIngredients(listedIngredients: listed, contains: contains,
        mayContain: mayContain, coveredAllergens: coverage,
        coveredOtherAllergies: otherCoverage, compatibleDietaryRules: dietary,
        coveredOtherDietaryRules: otherDietary, isComplete: complete),
        source: source ?? foodOfficialSource(), checkedAt: checkedAt ?? foodDate(),
        confidence: confidence, uncertainty: uncertainty)
}

func foodPrice(_ amount: Double, source: FoodEvidenceSource? = nil,
               checkedAt: Date? = nil) -> FoodEvidence<FoodPrice> {
    FoodEvidence(value: FoodPrice(amountSGD: amount), source: source ?? foodOfficialSource(),
                 checkedAt: checkedAt ?? foodDate(), confidence: .high)
}

func foodCandidate(_ id: String = "dish", ingredients: FoodEvidence<FoodIngredients>? = foodIngredients(),
                   price: FoodEvidence<FoodPrice>? = nil, place: FoodPlace? = foodPlace(),
                   mealTypes: [FoodMealType] = [.lunch], kitchen: FoodKitchenAccess = .none,
                   nutrition: FoodEvidence<FoodNutritionEstimate>? = nil,
                   officialMenu: FoodEvidence<URL>? = nil,
                   dishName: String = "Test rice", serving: String? = nil) -> FoodCandidate {
    FoodCandidate(id: id, dishName: dishName, place: place, mealTypes: mealTypes,
                  servingDescription: serving, requiredKitchen: kitchen,
                  ingredients: ingredients, price: price, nutrition: nutrition, officialMenu: officialMenu)
}

func foodRequest(allergens: [FoodAllergen] = [], otherAllergies: [String] = [],
                 dietary: [FoodDietaryRule] = [], otherDietary: [String] = [],
                 maxPrice: Double? = nil, dislikes: [String] = [],
                 area: String = "Campus", kitchen: FoodKitchenAccess = .none) -> FoodRequest {
    FoodRequest(mealType: .lunch, area: area, dietaryRules: dietary,
                otherDietaryRules: otherDietary, allergens: allergens,
                otherAllergies: otherAllergies, dislikes: dislikes, kitchenAccess: kitchen,
                maxPricePerMealSGD: maxPrice)
}

func foodAssessment(_ candidate: FoodCandidate, request: FoodRequest = foodRequest(),
                    now: Date = foodDate()) -> FoodAssessment {
    FoodSelector().assess(candidate, request: request, now: now)
}

func foodDraft(observedAt: Date = foodDate(), price: Double? = 5,
               dishName: String = "Remembered rice") -> FoodCorrectionDraft {
    FoodCorrectionDraft(candidateID: "saved-dish", dishName: dishName, place: foodPlace(),
                        mealTypes: [.lunch], observedAt: observedAt, priceSGD: price,
                        ingredientNotes: ["rice", "carrot"])
}

func foodProposal(draft: FoodCorrectionDraft = foodDraft(), profileID: UUID = UUID(),
                  isSample: Bool = false) -> FoodCorrectionProposal {
    FoodCorrectionProposal(id: UUID(), profileID: profileID, isSample: isSample,
                           createdAt: foodDate(), draft: draft)
}
