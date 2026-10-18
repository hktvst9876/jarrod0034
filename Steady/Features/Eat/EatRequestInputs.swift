import Foundation
import SteadyCore

struct EatRequestInputs: Equatable {
    var mealType: FoodMealType = .lunch
    var area = ""
    var dietaryRules: [FoodDietaryRule] = []
    var allergens: [FoodAllergen] = []
    var dislikes = ""
    var kitchenAccess: FoodKitchenAccess = .none
    var context = ""

    func request(profile: ProfileRecord, usingApproximateLocation: Bool = false) -> FoodRequest {
        FoodRequest(mealType: mealType, area: usingApproximateLocation ? "" : area,
            dietaryRules: dietaryRules,
            otherDietaryRules: Self.notes(profile.dietaryRulesText),
            allergens: allergens, otherAllergies: Self.notes(profile.allergiesText),
            dislikes: Self.notes(dislikes), kitchenAccess: kitchenAccess,
            maxPricePerMealSGD: profile.maxPricePerMealSGD, context: context)
    }

    static func notes(_ text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }
}

struct EatActionSource: Equatable {
    let dataRevision: Int
    let profileID: UUID
    let sample: Bool
    let day: Date
    let dietaryNotes: String
    let allergyNotes: String
    let maxPrice: Double?
    let lowDataMode: Bool
    let request: EatRequestInputs
    let revision: UUID
    let savedVersion: [FoodStoredVersion]
}

struct FoodStoredVersion: Equatable {
    let key: String
    let data: Data
    let updatedAt: Date
}

struct EatProfileScope: Equatable {
    let id: UUID
    let dietaryNotes: String
    let allergyNotes: String
    let maxPrice: Double?
    let lowDataMode: Bool
}

struct FoodEditorSource: Identifiable {
    let id = UUID()
    let candidate: FoodCandidate?
    let actionSource: EatActionSource
    let observedAt: Date
}

enum FoodDisplay {
    static func title(_ meal: FoodMealType) -> String { meal.rawValue.capitalized }
    static func title(_ rule: FoodDietaryRule) -> String {
        switch rule {
        case .vegetarian: "Vegetarian"
        case .vegan: "Vegan"
        case .halal: "Halal"
        case .noPork: "No pork"
        }
    }
    static func title(_ allergen: FoodAllergen) -> String {
        switch allergen {
        case .peanuts: "Peanuts"
        case .treeNuts: "Tree nuts"
        case .milk: "Milk"
        case .egg: "Egg"
        case .fish: "Fish"
        case .crustaceans: "Crustaceans"
        case .molluscs: "Molluscs"
        case .soy: "Soy"
        case .wheat: "Wheat"
        case .sesame: "Sesame"
        case .sulphites: "Sulphites"
        }
    }
    static func title(_ kitchen: FoodKitchenAccess) -> String {
        switch kitchen {
        case .none: "No kitchen"
        case .microwaveKettle: "Microwave and kettle"
        case .fullKitchen: "Full kitchen"
        }
    }
    static func date(_ value: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = SteadyCalendar.singapore()
        formatter.timeZone = formatter.calendar.timeZone
        formatter.locale = Locale(identifier: "en_SG")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: value)
    }
    static func price(_ value: Double) -> String {
        value.formatted(.currency(code: "SGD"))
    }
}
