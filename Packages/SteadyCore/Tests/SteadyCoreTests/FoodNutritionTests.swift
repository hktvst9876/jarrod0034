import Foundation
import Testing
@testable import SteadyCore

private func foodReference(dish: String = "Reference rice", serving: String = "one reference bowl",
                           recordID: String = "test-record-only",
                           url: String = "https://www.hpb.gov.sg/sgfoodid/record/test-record-only",
                           checkedAt: Date = foodDate()) -> SGFoodIDRecord {
    SGFoodIDRecord(recordID: recordID, dishName: dish, servingDescription: serving,
        estimate: FoodNutritionEstimate(energyKcalLower: 100, energyKcalUpper: 200,
            proteinGramsLower: 3, proteinGramsUpper: 5, portionAssumptions: "Test-only range; not production food data",
            matchedDishName: dish, matchedServingDescription: serving),
        sourceURL: URL(string: url)!, checkedAt: checkedAt)
}

@Test func foodNoUnverifiedNutritionIsShippedInProductionCatalog() {
    #expect(FoodNutritionMatcher.verifiedCatalog.isEmpty)
}

@Test func foodNutritionRequiresExactDishAndServingRecordMatch() {
    let record = foodReference()
    #expect(FoodNutritionMatcher.match(record: record, dishName: "Reference rice",
        servingDescription: "one reference bowl", now: foodDate()) != nil)
    #expect(FoodNutritionMatcher.match(record: record, dishName: "Similar rice",
        servingDescription: "one reference bowl", now: foodDate()) == nil)
    #expect(FoodNutritionMatcher.match(record: record, dishName: "Reference rice",
        servingDescription: "large bowl", now: foodDate()) == nil)
}

@Test func foodNutritionRejectsForgedEmptyAndStaleCitation() {
    for record in [foodReference(recordID: ""), foodReference(url: "https://hpb.gov.sg.evil.example/record"),
                   foodReference(url: "http://www.hpb.gov.sg/record"),
                   foodReference(checkedAt: foodDate().addingTimeInterval(1)),
                   foodReference(checkedAt: foodDate().addingTimeInterval(-31_536_001))] {
        #expect(FoodNutritionMatcher.match(record: record, dishName: record.dishName,
            servingDescription: record.servingDescription, now: foodDate()) == nil)
    }
}

@Test func foodNutritionEstimateIsBoundToCandidateServingAndDish() {
    let record = foodReference()
    let evidence = FoodNutritionMatcher.match(record: record, dishName: record.dishName,
        servingDescription: record.servingDescription, now: foodDate())!
    let correct = foodCandidate(nutrition: evidence, dishName: record.dishName, serving: record.servingDescription)
    #expect(foodAssessment(correct).approvedNutrition == evidence)
    #expect(foodAssessment(foodCandidate(nutrition: evidence, dishName: record.dishName)).approvedNutrition == nil)
    #expect(foodAssessment(foodCandidate(nutrition: evidence, dishName: "Different dish", serving: record.servingDescription))
        .approvedNutrition == nil)
}

@Test func foodInvalidNutritionRangeCannotBeApproved() {
    let estimate = FoodNutritionEstimate(energyKcalLower: 200, energyKcalUpper: 100,
        portionAssumptions: "Reference serving", matchedDishName: "Test rice", matchedServingDescription: "bowl")
    let evidence = FoodEvidence(value: estimate, source: foodOfficialSource(), checkedAt: foodDate(), confidence: .high)
    #expect(foodAssessment(foodCandidate(nutrition: evidence, serving: "bowl")).approvedNutrition == nil)
}

@Test func foodNutritionLabelAlwaysCarriesPortionUncertaintyAndCitation() {
    let record = foodReference()
    let result = FoodNutritionMatcher.match(record: record, dishName: record.dishName,
        servingDescription: record.servingDescription, now: foodDate())!
    #expect(result.source.recordID == record.recordID)
    #expect(result.source.url == record.sourceURL)
    #expect(result.checkedAt == record.checkedAt)
    #expect(result.confidence == .moderate)
    #expect(!result.uncertainty.isEmpty)
    #expect(!result.value.portionAssumptions.isEmpty)
}
