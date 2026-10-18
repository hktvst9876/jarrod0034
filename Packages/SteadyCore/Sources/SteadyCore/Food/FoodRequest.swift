import Foundation

public enum FoodMealType: String, CaseIterable, Codable, Sendable {
    case breakfast, lunch, dinner, snack
}

public enum FoodKitchenAccess: String, CaseIterable, Codable, Sendable {
    case none, microwaveKettle, fullKitchen

    var capacity: Int {
        switch self {
        case .none: 0
        case .microwaveKettle: 1
        case .fullKitchen: 2
        }
    }
}

public enum FoodDietaryRule: String, CaseIterable, Codable, Sendable {
    case vegetarian, vegan, halal, noPork
}

public enum FoodAllergen: String, CaseIterable, Codable, Sendable {
    case peanuts, treeNuts, milk, egg, fish, crustaceans, molluscs, soy, wheat, sesame, sulphites
}

public struct FoodCoordinate: Codable, Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    public var isValid: Bool {
        latitude.isFinite && longitude.isFinite
            && (-90...90).contains(latitude) && (-180...180).contains(longitude)
    }
}

public struct FoodPlace: Codable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let area: String
    /// A directory website is not an identity-checked menu link.
    public let websiteURL: URL?
    public let coordinate: FoodCoordinate?
    public let checkedAt: Date

    public init(id: String, name: String, area: String, websiteURL: URL? = nil,
                coordinate: FoodCoordinate? = nil, checkedAt: Date) {
        self.id = id
        self.name = name
        self.area = area
        self.websiteURL = websiteURL
        self.coordinate = coordinate
        self.checkedAt = checkedAt
    }
}

public struct FoodRequest: Codable, Equatable, Sendable {
    public let mealType: FoodMealType
    public let area: String
    public let dietaryRules: [FoodDietaryRule]
    public let otherDietaryRules: [String]
    public let allergens: [FoodAllergen]
    public let otherAllergies: [String]
    public let dislikes: [String]
    public let kitchenAccess: FoodKitchenAccess
    public let maxPricePerMealSGD: Double?
    /// Explicit user text only; never interpreted as medical context.
    public let context: String

    public init(mealType: FoodMealType, area: String,
                dietaryRules: [FoodDietaryRule] = [], otherDietaryRules: [String] = [],
                allergens: [FoodAllergen] = [], otherAllergies: [String] = [],
                dislikes: [String] = [], kitchenAccess: FoodKitchenAccess = .none,
                maxPricePerMealSGD: Double? = nil, context: String = "") {
        self.mealType = mealType
        self.area = area
        self.dietaryRules = dietaryRules
        self.otherDietaryRules = otherDietaryRules
        self.allergens = allergens
        self.otherAllergies = otherAllergies
        self.dislikes = dislikes
        self.kitchenAccess = kitchenAccess
        self.maxPricePerMealSGD = maxPricePerMealSGD
        self.context = context
    }
}

enum FoodText {
    static func key(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_SG"))
            .split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    static func keys(_ values: [String]) -> [String] {
        values.map(key).filter { !$0.isEmpty }
    }
}
