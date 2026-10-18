import Foundation
import Testing
@testable import SteadyCore

@Test func foodUnknownIngredientsNeverBecomePrimary() {
    let selection = FoodSelector.select(candidates: [foodCandidate(ingredients: nil)],
                                        request: foodRequest(), now: foodDate())
    #expect(selection.primary.isEmpty)
    #expect(selection.requiresConfirmation.count == 1)
}

@Test func foodKnownAllergenConflictIsExcluded() {
    let result = foodAssessment(foodCandidate(ingredients: foodIngredients(contains: [.peanuts])),
                                request: foodRequest(allergens: [.peanuts]))
    #expect(result.eligibility == .excluded)
}

@Test func foodKnownCrossContactIsExcluded() {
    #expect(foodAssessment(foodCandidate(ingredients: foodIngredients(mayContain: [.milk])),
                           request: foodRequest(allergens: [.milk])).eligibility == .excluded)
}

@Test func foodStaleLowConfidenceConflictRemainsExcluded() {
    let ingredients = foodIngredients(contains: [.egg], complete: false,
        checkedAt: foodDate().addingTimeInterval(-2_592_001), confidence: .low)
    #expect(foodAssessment(foodCandidate(ingredients: ingredients),
                           request: foodRequest(allergens: [.egg])).eligibility == .excluded)
}

@Test func foodListedKnownIngredientCannotBeClearedByEmptyContainsList() {
    let ingredients = foodIngredients(listed: ["rice", "peanut oil"])
    #expect(foodAssessment(foodCandidate(ingredients: ingredients),
                           request: foodRequest(allergens: [.peanuts])).eligibility == .excluded)
}

@Test func foodCanonicalPositiveAliasAddsExclusionButNotCoverage() {
    let tofu = foodIngredients(listed: ["tofu"], coverage: [])
    #expect(foodAssessment(foodCandidate(ingredients: tofu),
                           request: foodRequest(allergens: [.soy])).eligibility == .excluded)
    #expect(foodAssessment(foodCandidate(ingredients: foodIngredients(coverage: [])),
                           request: foodRequest(allergens: [.soy])).eligibility == .requiresConfirmation)
}

@Test func foodOtherAllergyNeedsExactExplicitCoverage() {
    let candidate = foodCandidate(ingredients: foodIngredients(otherCoverage: ["chilli"]))
    #expect(foodAssessment(candidate, request: foodRequest(otherAllergies: [" Chilli "])).eligibility == .eligible)
    #expect(foodAssessment(candidate, request: foodRequest(otherAllergies: ["chili pepper"])).eligibility == .requiresConfirmation)
}

@Test func foodOtherAllergyPositiveIngredientIsExcluded() {
    let candidate = foodCandidate(ingredients: foodIngredients(listed: ["rice", "chilli paste"]))
    #expect(foodAssessment(candidate, request: foodRequest(otherAllergies: ["chilli"])).eligibility == .excluded)
}

@Test func foodUnknownOtherAllergyIsNotSilentlyDropped() {
    #expect(foodAssessment(foodCandidate(), request: foodRequest(otherAllergies: ["my unusual allergy"]))
        .eligibility == .requiresConfirmation)
}

@Test func foodDietaryRulesNeedExplicitEvidenceNotDishName() {
    #expect(foodAssessment(foodCandidate(dishName: "Vegan rice"), request: foodRequest(dietary: [.vegan]))
        .eligibility == .requiresConfirmation)
    #expect(foodAssessment(foodCandidate(ingredients: foodIngredients(dietary: [.vegan])),
                           request: foodRequest(dietary: [.vegan])).eligibility == .eligible)
}

@Test func foodOtherDietaryRuleMustBeCoveredExactly() {
    #expect(foodAssessment(foodCandidate(), request: foodRequest(otherDietary: ["religious rule"]))
        .eligibility == .requiresConfirmation)
}

@Test func foodIngredientUncertaintyAndIncompleteListsBlockPrimary() {
    #expect(foodAssessment(foodCandidate(ingredients: foodIngredients(complete: false))).eligibility == .requiresConfirmation)
    #expect(foodAssessment(foodCandidate(ingredients: foodIngredients(uncertainty: ["Sauce unknown"])))
        .eligibility == .requiresConfirmation)
    #expect(foodAssessment(foodCandidate(ingredients: foodIngredients(confidence: .moderate)))
        .eligibility == .requiresConfirmation)
}

@Test func foodIngredientFreshnessIsConservativeAtBoundary() {
    #expect(foodAssessment(foodCandidate(ingredients: foodIngredients(
        checkedAt: foodDate().addingTimeInterval(-86_400)))).eligibility == .eligible)
    #expect(foodAssessment(foodCandidate(ingredients: foodIngredients(
        checkedAt: foodDate().addingTimeInterval(-86_401)))).eligibility == .requiresConfirmation)
    #expect(foodAssessment(foodCandidate(ingredients: foodIngredients(
        checkedAt: foodDate().addingTimeInterval(1)))).eligibility == .requiresConfirmation)
}

@Test func foodSavedIngredientsNeverProvideCurrentAllergenAssurance() {
    let source = FoodEvidenceSource(kind: .userSaved, title: "Prior visit", recordID: "saved")
    let candidate = foodCandidate(ingredients: foodIngredients(source: source))
    #expect(foodAssessment(candidate).eligibility == .requiresConfirmation)
    #expect(foodAssessment(candidate, request: foodRequest(allergens: [.milk])).eligibility == .requiresConfirmation)
}
