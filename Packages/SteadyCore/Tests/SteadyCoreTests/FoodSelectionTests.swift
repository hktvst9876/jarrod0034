import Foundation
import Testing
@testable import SteadyCore

@Test func foodSelectionHasAtMostThreeTotalDistinctChoices() {
    let candidates = (0..<5).map { foodCandidate("dish-\($0)", dishName: "Rice \($0)") }
        + [foodCandidate("unknown", ingredients: nil, dishName: "Unknown dish")]
    let result = FoodSelector.select(candidates: candidates, request: foodRequest(), now: foodDate())
    #expect(result.primary.count == 3)
    #expect(result.requiresConfirmation.isEmpty)
}

@Test func foodNoEligibleChoicesDoesNotPadWithUnknownPrimaryResults() {
    let result = FoodSelector.select(candidates: [], request: foodRequest(), now: foodDate())
    #expect(result == FoodSelection())
    let unknown = FoodSelector.select(candidates: [FoodCandidate.discoveredPlace(foodPlace())],
                                      request: foodRequest(), now: foodDate())
    #expect(unknown.primary.isEmpty)
    #expect(unknown.requiresConfirmation.count == 1)
}

@Test func foodDuplicateDishPlaceAndIDDoNotFillTheCount() {
    let duplicate = foodCandidate("duplicate")
    let sameDish = foodCandidate("different-id")
    let result = FoodSelector.select(candidates: [duplicate, duplicate, sameDish], request: foodRequest(), now: foodDate())
    #expect(result.primary.count == 1)
}

@Test func foodRepeatedSavedDishLabelsCannotFillTheCountWithNewLocalIDs() {
    let firstProposal = foodProposal()
    let secondProposal = foodProposal(profileID: firstProposal.profileID)
    let first = FoodCorrectionReducer.confirm(proposal: firstProposal, profileID: firstProposal.profileID,
        isSample: false, now: foodDate())!
    let second = FoodCorrectionReducer.confirm(proposal: secondProposal, profileID: secondProposal.profileID,
        isSample: false, now: foodDate())!
    let copy = FoodCandidate(id: "another-local-dish", dishName: second.candidate.dishName,
        place: second.candidate.place, mealTypes: second.candidate.mealTypes,
        ingredients: second.candidate.ingredients, price: second.candidate.price)
    #expect(first.candidate.place?.id != copy.place?.id)
    let result = FoodSelector.select(candidates: [first.candidate, copy], request: foodRequest(), now: foodDate())
    #expect(result.primary.isEmpty)
    #expect(result.requiresConfirmation.count == 1)
    #expect(result == FoodSelector.select(candidates: [copy, first.candidate], request: foodRequest(), now: foodDate()))
}

@Test func foodDuplicateConflictWinsOverAnEligibleCopy() {
    let result = FoodSelector.select(candidates: [foodCandidate(), foodCandidate(ingredients: foodIngredients(contains: [.milk]))],
                                      request: foodRequest(allergens: [.milk]), now: foodDate())
    #expect(result.primary.isEmpty)
    #expect(result.excluded.count == 1)
}

@Test func foodPriceLimitIsPerItemAndUnknownIsNotAffordable() {
    let unknown = foodAssessment(foodCandidate(), request: foodRequest(maxPrice: 6))
    #expect(unknown.eligibility == .requiresConfirmation)
    #expect(foodAssessment(foodCandidate(price: foodPrice(7)), request: foodRequest(maxPrice: 6)).eligibility == .excluded)
    #expect(foodAssessment(foodCandidate(price: foodPrice(6)), request: foodRequest(maxPrice: 6)).eligibility == .eligible)
}

@Test func foodKnownSavedOverMaximumIsExcludedWithoutClaimingCurrentPrice() {
    let source = FoodEvidenceSource(kind: .userSaved, title: "Saved from prior visit", recordID: "saved")
    #expect(foodAssessment(foodCandidate(price: foodPrice(7, source: source)), request: foodRequest(maxPrice: 6))
        .eligibility == .excluded)
    #expect(foodAssessment(foodCandidate(price: foodPrice(5, source: source)), request: foodRequest(maxPrice: 6))
        .eligibility == .requiresConfirmation)
}

@Test func foodInvalidMaximumNeedsReview() {
    for maximum in [-1, Double.nan, .infinity] {
        #expect(foodAssessment(foodCandidate(price: foodPrice(5)), request: foodRequest(maxPrice: maximum))
            .eligibility == .requiresConfirmation)
    }
}

@Test func foodMealKitchenAndDislikeRestrictionsAreDeterministic() {
    #expect(foodAssessment(foodCandidate(mealTypes: [.breakfast])).eligibility == .excluded)
    #expect(foodAssessment(foodCandidate(kitchen: .fullKitchen)).eligibility == .excluded)
    #expect(foodAssessment(foodCandidate(kitchen: .microwaveKettle),
        request: foodRequest(kitchen: .fullKitchen)).eligibility == .eligible)
    #expect(foodAssessment(foodCandidate(dishName: "Chilli rice"), request: foodRequest(dislikes: ["chilli"]))
        .eligibility == .excluded)
}

@Test func foodSavedOtherAreaDoesNotRankAsNearby() {
    let source = FoodEvidenceSource(kind: .userSaved, title: "Prior visit", recordID: "saved")
    let candidate = foodCandidate(ingredients: foodIngredients(source: source), place: foodPlace(area: "Other campus"))
    #expect(foodAssessment(candidate, request: foodRequest(area: "Campus")).eligibility == .excluded)
}

@Test func foodDeterministicOrderUsesKnownPriceWithoutInventedValues() {
    let candidates = [foodCandidate("b", price: foodPrice(6), dishName: "B rice"),
                      foodCandidate("a", price: foodPrice(5), dishName: "A rice"),
                      foodCandidate("c", dishName: "C rice")]
    let result = FoodSelector.select(candidates: candidates, request: foodRequest(), now: foodDate())
    let reversed = FoodSelector.select(candidates: Array(candidates.reversed()), request: foodRequest(), now: foodDate())
    #expect(result == reversed)
    #expect(result.primary.map(\.candidate.id) == ["a", "b", "c"])
}

@Test func foodManualOfflineSavedFallbackHasNoNetworkRequirement() {
    let proposal = foodProposal()
    let saved = FoodCorrectionReducer.confirm(proposal: proposal, profileID: proposal.profileID,
                                              isSample: false, now: foodDate())!
    let result = FoodSelector.select(candidates: [saved.candidate], request: foodRequest(), now: foodDate())
    #expect(result.primary.isEmpty)
    #expect(result.requiresConfirmation.count == 1)
    #expect(result.requiresConfirmation.first?.approvedPrice?.value.amountSGD == 5)
}

@Test func foodSameRankIdentityAndNameDuplicateFactsHaveStableRepresentative() {
    let first = foodCandidate(ingredients: foodIngredients(listed: ["rice", "carrot"]), price: foodPrice(5))
    let second = foodCandidate(ingredients: foodIngredients(listed: ["rice", "broccoli"]), price: foodPrice(5))
    let result = FoodSelector.select(candidates: [first, second], request: foodRequest(), now: foodDate())
    let reversed = FoodSelector.select(candidates: [second, first], request: foodRequest(), now: foodDate())
    #expect(result == reversed)
    #expect(result.primary.count == 1)
    let conflict = foodCandidate(ingredients: foodIngredients(contains: [.milk]), price: foodPrice(5))
    let restricted = FoodSelector.select(candidates: [first, second, conflict], request: foodRequest(allergens: [.milk]), now: foodDate())
    let restrictedReversed = FoodSelector.select(candidates: [conflict, second, first], request: foodRequest(allergens: [.milk]), now: foodDate())
    #expect(restricted == restrictedReversed)
    #expect(restricted.primary.isEmpty)
    #expect(restricted.excluded.count == 1)
}
