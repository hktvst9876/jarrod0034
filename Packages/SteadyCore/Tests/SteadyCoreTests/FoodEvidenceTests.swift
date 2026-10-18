import Foundation
import Testing
@testable import SteadyCore

@Test func foodDirectoryWebsiteNeverBecomesOfficialMenuOrPrice() {
    let place = foodPlace()
    let discovery = FoodCandidate.discoveredPlace(place)
    let result = foodAssessment(discovery)
    #expect(result.eligibility == .requiresConfirmation)
    #expect(result.approvedMenu == nil)
    #expect(result.approvedPrice == nil)
    #expect(result.approvedNutrition == nil)
}

@Test func foodOfficialEvidenceRequiresIdentityFlagMatchingPlaceAndHost() {
    let sources = [foodOfficialSource(identityMatched: false), foodOfficialSource(placeID: "different"),
                   foodOfficialSource(url: "https://other.example/menu"),
                   foodOfficialSource(url: "http://venue.example/menu")]
    for source in sources {
        let candidate = foodCandidate(ingredients: foodIngredients(source: source), price: foodPrice(5, source: source))
        let result = foodAssessment(candidate)
        #expect(result.eligibility == .requiresConfirmation)
        #expect(result.approvedPrice == nil)
    }
}

@Test func foodMissingOfficialSourceTitleOrURLIsRejected() {
    let sources = [FoodEvidenceSource(kind: .officialMenu, title: "", url: URL(string: "https://venue.example/menu"),
                                      placeID: "venue", identityMatched: true),
                   FoodEvidenceSource(kind: .officialMenu, title: "Menu", placeID: "venue", identityMatched: true)]
    for source in sources {
        #expect(foodAssessment(foodCandidate(ingredients: foodIngredients(source: source))).eligibility == .requiresConfirmation)
    }
}

@Test func foodLegacyAndMapKitCannotVerifyFoodFacts() {
    for kind in [FoodSourceKind.legacyFixture, .mapKit] {
        let source = FoodEvidenceSource(kind: kind, title: "Old fixture", url: URL(string: "https://venue.example/menu"),
                                        placeID: "venue", identityMatched: true)
        let result = foodAssessment(foodCandidate(ingredients: foodIngredients(source: source), price: foodPrice(5, source: source)))
        #expect(result.eligibility == .requiresConfirmation)
        #expect(result.approvedPrice == nil)
    }
}

@Test func foodCorruptAndFutureCheckTimesDoNotPromoteFacts() {
    for date in [Date(timeIntervalSinceReferenceDate: .infinity),
                 Date(timeIntervalSinceReferenceDate: .nan), foodDate().addingTimeInterval(1)] {
        let result = foodAssessment(foodCandidate(ingredients: foodIngredients(checkedAt: date), price: foodPrice(5, checkedAt: date)))
        #expect(result.eligibility == .requiresConfirmation)
        #expect(result.approvedPrice == nil)
    }
}

@Test func foodInvalidAndStalePricesStayUnknown() {
    for amount in [-1, Double.nan, .infinity] {
        #expect(foodAssessment(foodCandidate(price: foodPrice(amount))).approvedPrice == nil)
    }
    #expect(foodAssessment(foodCandidate(price: foodPrice(5,
        checkedAt: foodDate().addingTimeInterval(-2_592_001)))).approvedPrice == nil)
}

@Test func foodOfficialMenuValueCannotPointAwayFromItsCitation() {
    let mismatched = FoodEvidence(value: URL(string: "https://evil.example")!, source: foodOfficialSource(),
                                  checkedAt: foodDate(), confidence: .high)
    #expect(foodAssessment(foodCandidate(officialMenu: mismatched)).approvedMenu == nil)
    let matched = FoodEvidence(value: URL(string: "https://venue.example/menu")!, source: foodOfficialSource(),
                               checkedAt: foodDate(), confidence: .high)
    #expect(foodAssessment(foodCandidate(officialMenu: matched)).approvedMenu == matched)
}

@Test func foodFreshSavedPriceHasPriorVisitSourceNotOfficialConfidence() {
    let proposal = foodProposal()
    let saved = FoodCorrectionReducer.confirm(proposal: proposal, profileID: proposal.profileID,
                                              isSample: false, now: foodDate())!
    let price = foodAssessment(saved.candidate).approvedPrice
    #expect(price?.source.kind == .userSaved)
    #expect(price?.source.title == "Saved from prior visit")
    #expect(price?.checkedAt == proposal.draft.observedAt)
    #expect(price?.confidence == .low)
    #expect(price?.uncertainty.isEmpty == false)
}

@Test func foodFreeAllergyAliasConflictsWithTypedOrListedEvidence() {
    #expect(foodAssessment(foodCandidate(ingredients: foodIngredients(contains: [.milk])),
        request: foodRequest(otherAllergies: ["dairy"])).eligibility == .excluded)
    #expect(foodAssessment(foodCandidate(ingredients: foodIngredients(listed: ["cream"])),
        request: foodRequest(otherAllergies: ["allergic to milk"])).eligibility == .excluded)
}

@Test func foodContradictoryDietaryEvidenceCannotClaimEligibility() {
    let cases: [(FoodDietaryRule, String)] = [(.vegan, "egg"), (.vegan, "milk"),
        (.vegetarian, "fish"), (.vegetarian, "chicken"), (.noPork, "pork"), (.halal, "pork")]
    for (rule, ingredient) in cases {
        let candidate = foodCandidate(ingredients: foodIngredients(listed: [ingredient], dietary: [rule]))
        #expect(foodAssessment(candidate, request: foodRequest(dietary: [rule])).eligibility == .excluded)
    }
}

@Test func foodFreeAllergyAliasesInOtherKnownEvidenceRemainExclusions() {
    let ingredients = FoodIngredients(listedIngredients: ["rice"], otherKnownAllergens: ["dairy"],
        coveredOtherAllergies: ["milk"], isComplete: true)
    let evidence = FoodEvidence(value: ingredients, source: foodOfficialSource(),
                                checkedAt: foodDate(), confidence: .high)
    #expect(foodAssessment(foodCandidate(ingredients: evidence),
                           request: foodRequest(otherAllergies: ["milk"])).eligibility == .excluded)
}

@Test func foodOtherKnownAllergenNotesCannotContradictDietarySuitability() {
    let ingredients = FoodIngredients(listedIngredients: ["rice"], otherKnownAllergens: ["dairy"],
        compatibleDietaryRules: [.vegan], isComplete: true)
    let evidence = FoodEvidence(value: ingredients, source: foodOfficialSource(),
                                checkedAt: foodDate(), confidence: .high)
    #expect(foodAssessment(foodCandidate(ingredients: evidence),
                           request: foodRequest(dietary: [.vegan])).eligibility == .excluded)
}
