import Foundation

public struct FoodIngredients: Codable, Equatable, Sendable {
    public let listedIngredients: [String]
    public let contains: [FoodAllergen]
    public let mayContain: [FoodAllergen]
    public let otherKnownAllergens: [String]
    public let coveredAllergens: [FoodAllergen]
    public let coveredOtherAllergies: [String]
    public let compatibleDietaryRules: [FoodDietaryRule]
    public let coveredOtherDietaryRules: [String]
    public let isComplete: Bool

    public init(listedIngredients: [String] = [], contains: [FoodAllergen] = [],
                mayContain: [FoodAllergen] = [],
                otherKnownAllergens: [String] = [], coveredAllergens: [FoodAllergen] = [],
                coveredOtherAllergies: [String] = [], compatibleDietaryRules: [FoodDietaryRule] = [],
                coveredOtherDietaryRules: [String] = [], isComplete: Bool = false) {
        self.listedIngredients = listedIngredients
        self.contains = contains
        self.mayContain = mayContain
        self.otherKnownAllergens = otherKnownAllergens
        self.coveredAllergens = coveredAllergens
        self.coveredOtherAllergies = coveredOtherAllergies
        self.compatibleDietaryRules = compatibleDietaryRules
        self.coveredOtherDietaryRules = coveredOtherDietaryRules
        self.isComplete = isComplete
    }
}

public struct FoodPrice: Codable, Equatable, Sendable {
    public let amountSGD: Double
    public let portion: String

    public init(amountSGD: Double, portion: String = "per dish") {
        self.amountSGD = amountSGD
        self.portion = portion
    }

    var isValid: Bool { amountSGD.isFinite && amountSGD >= 0 && !FoodText.key(portion).isEmpty }
}

public struct FoodNutritionEstimate: Codable, Equatable, Sendable {
    public let energyKcalLower: Double
    public let energyKcalUpper: Double
    public let proteinGramsLower: Double?
    public let proteinGramsUpper: Double?
    public let portionAssumptions: String
    public let matchedDishName: String
    public let matchedServingDescription: String

    public init(energyKcalLower: Double, energyKcalUpper: Double,
                proteinGramsLower: Double? = nil, proteinGramsUpper: Double? = nil,
                portionAssumptions: String, matchedDishName: String, matchedServingDescription: String) {
        self.energyKcalLower = energyKcalLower
        self.energyKcalUpper = energyKcalUpper
        self.proteinGramsLower = proteinGramsLower
        self.proteinGramsUpper = proteinGramsUpper
        self.portionAssumptions = portionAssumptions
        self.matchedDishName = matchedDishName
        self.matchedServingDescription = matchedServingDescription
    }

    var isValid: Bool {
        guard energyKcalLower.isFinite, energyKcalUpper.isFinite, energyKcalLower >= 0,
              energyKcalUpper >= energyKcalLower, !FoodText.key(portionAssumptions).isEmpty,
              !FoodText.key(matchedDishName).isEmpty,
              !FoodText.key(matchedServingDescription).isEmpty else { return false }
        switch (proteinGramsLower, proteinGramsUpper) {
        case (nil, nil): return true
        case let (.some(lower), .some(upper)):
            return lower.isFinite && upper.isFinite && lower >= 0 && upper >= lower
        default: return false
        }
    }
}

public struct FoodCandidate: Codable, Equatable, Sendable {
    public let id: String
    public let dishName: String
    public let place: FoodPlace?
    public let mealTypes: [FoodMealType]
    public let servingDescription: String?
    public let requiredKitchen: FoodKitchenAccess
    public let ingredients: FoodEvidence<FoodIngredients>?
    public let price: FoodEvidence<FoodPrice>?
    public let nutrition: FoodEvidence<FoodNutritionEstimate>?
    public let officialMenu: FoodEvidence<URL>?

    public init(id: String, dishName: String, place: FoodPlace? = nil,
                mealTypes: [FoodMealType] = [], servingDescription: String? = nil,
                requiredKitchen: FoodKitchenAccess = .none,
                ingredients: FoodEvidence<FoodIngredients>? = nil,
                price: FoodEvidence<FoodPrice>? = nil,
                nutrition: FoodEvidence<FoodNutritionEstimate>? = nil,
                officialMenu: FoodEvidence<URL>? = nil) {
        self.id = id
        self.dishName = dishName
        self.place = place
        self.mealTypes = mealTypes
        self.servingDescription = servingDescription
        self.requiredKitchen = requiredKitchen
        self.ingredients = ingredients
        self.price = price
        self.nutrition = nutrition
        self.officialMenu = officialMenu
    }

    public static func discoveredPlace(_ place: FoodPlace) -> FoodCandidate {
        FoodCandidate(id: "place:" + place.id, dishName: place.name, place: place)
    }
}
