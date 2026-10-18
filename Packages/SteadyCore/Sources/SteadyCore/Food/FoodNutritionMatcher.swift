import Foundation

/// A manually vetted cited record, not a search result or a fabricated food database entry.
public struct SGFoodIDRecord: Codable, Equatable, Sendable {
    public let recordID: String
    public let dishName: String
    public let servingDescription: String
    public let estimate: FoodNutritionEstimate
    public let sourceURL: URL
    public let checkedAt: Date

    public init(recordID: String, dishName: String, servingDescription: String,
                estimate: FoodNutritionEstimate, sourceURL: URL, checkedAt: Date) {
        self.recordID = recordID
        self.dishName = dishName
        self.servingDescription = servingDescription
        self.estimate = estimate
        self.sourceURL = sourceURL
        self.checkedAt = checkedAt
    }
}

public enum FoodNutritionMatcher {
    /// No live SG FoodID record has yet been curated into this release. Unknown remains unavailable.
    public static let verifiedCatalog: [SGFoodIDRecord] = []

    public static func match(record: SGFoodIDRecord, dishName: String, servingDescription: String,
                             now: Date, policy: FoodEvidencePolicy = FoodEvidencePolicy())
        -> FoodEvidence<FoodNutritionEstimate>? {
        guard record.estimate.isValid,
              FoodText.key(dishName) == FoodText.key(record.dishName),
              FoodText.key(servingDescription) == FoodText.key(record.servingDescription),
              FoodText.key(record.estimate.matchedDishName) == FoodText.key(record.dishName),
              FoodText.key(record.estimate.matchedServingDescription) == FoodText.key(record.servingDescription)
        else { return nil }
        let source = FoodEvidenceSource(kind: .sgFoodID, title: "HPB SG FoodID: " + record.dishName,
                                        url: record.sourceURL, recordID: record.recordID)
        let evidence = FoodEvidence(value: record.estimate, source: source, checkedAt: record.checkedAt,
            confidence: .moderate,
            uncertainty: ["Reference serving match only; recipe, portion size, and preparation can vary."])
        guard FoodProvenance.foodID(source),
              policy.isFresh(evidence, now: now, maxAge: policy.nutritionMaxAge) else { return nil }
        return evidence
    }
}
