import Foundation

/// Decode-only representation of the starter alternative fixtures.
/// These values are not treated as verified wellness or food advice.
public struct LegacyAlternativeSeed: Decodable, Equatable, Sendable {
    public let version: Int
    public let updated: String
    public let notes: String
    public let barriers: [LegacyBarrier]
    public let plans: [LegacyAlternativePlan]
}

public struct LegacyBarrier: Decodable, Equatable, Sendable {
    public let id: String
    public let label: String
}

public struct LegacyAlternativePlan: Decodable, Equatable, Sendable {
    public let planType: String
    public let outcome: String
    public let options: [String: [LegacyAlternativeOption]]

    private enum CodingKeys: String, CodingKey {
        case planType = "plan_type"
        case outcome
        case options
    }
}

public struct LegacyAlternativeOption: Decodable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let minutes: Int
    public let effort: Int
    public let keeps: String
    public let givesUp: String
    public let steps: [String]
    public let isRest: Bool?
    public let isWait: Bool?
    public let isPlannedTreat: Bool?
    public let priceSGD: Decimal?

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case minutes
        case effort
        case keeps
        case givesUp = "gives_up"
        case steps
        case isRest = "is_rest"
        case isWait = "is_wait"
        case isPlannedTreat = "is_planned_treat"
        case priceSGD = "price_sgd"
    }
}

/// Decode-only representation of the starter food fixtures.
/// Phase 1 uses this only to prove bundle/resource wiring.
public struct LegacyFoodSeed: Decodable, Equatable, Sendable {
    public let version: Int
    public let updated: String
    public let notes: String
    public let dishes: [LegacyDish]
    public let groceries: [LegacyGrocery]
}

public struct LegacyDish: Decodable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let place: String
    public let priceSGD: Decimal
    public let priceSource: String
    public let kcalMin: Int
    public let kcalMax: Int
    public let proteinMin: Int
    public let proteinMax: Int
    public let contains: [String]
    public let containsConfidence: String
    public let diet: String
    public let needsKitchen: String
    public let tags: [String]
    public let orderTip: String

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case place
        case priceSGD = "price_sgd"
        case priceSource = "price_source"
        case kcalMin = "kcal_min"
        case kcalMax = "kcal_max"
        case proteinMin = "protein_min"
        case proteinMax = "protein_max"
        case contains
        case containsConfidence = "contains_confidence"
        case diet
        case needsKitchen = "needs_kitchen"
        case tags
        case orderTip = "order_tip"
    }
}

public struct LegacyGrocery: Decodable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let store: String
    public let priceSGD: Decimal
    public let priceConfidence: String
    public let validUntil: String?
    public let note: String
    public let forKitchen: String
    public let diet: String

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case store
        case priceSGD = "price_sgd"
        case priceConfidence = "price_confidence"
        case validUntil = "valid_until"
        case note
        case forKitchen = "for_kitchen"
        case diet
    }
}
