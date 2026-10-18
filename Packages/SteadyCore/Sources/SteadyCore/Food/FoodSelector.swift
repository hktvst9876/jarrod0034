import Foundation

public enum FoodEligibility: String, Codable, Sendable {
    case eligible, requiresConfirmation, excluded
}

public struct FoodAssessment: Codable, Equatable, Sendable {
    public let candidate: FoodCandidate
    public let eligibility: FoodEligibility
    public let reasons: [String]
    public let approvedPrice: FoodEvidence<FoodPrice>?
    public let approvedNutrition: FoodEvidence<FoodNutritionEstimate>?
    public let approvedMenu: FoodEvidence<URL>?

    public init(candidate: FoodCandidate, eligibility: FoodEligibility, reasons: [String],
                approvedPrice: FoodEvidence<FoodPrice>? = nil,
                approvedNutrition: FoodEvidence<FoodNutritionEstimate>? = nil,
                approvedMenu: FoodEvidence<URL>? = nil) {
        self.candidate = candidate
        self.eligibility = eligibility
        self.reasons = reasons
        self.approvedPrice = approvedPrice
        self.approvedNutrition = approvedNutrition
        self.approvedMenu = approvedMenu
    }
}

public struct FoodSelection: Codable, Equatable, Sendable {
    public let primary: [FoodAssessment]
    public let requiresConfirmation: [FoodAssessment]
    /// Exclusions are diagnostic, never recommendations.
    public let excluded: [FoodAssessment]

    public init(primary: [FoodAssessment] = [], requiresConfirmation: [FoodAssessment] = [],
                excluded: [FoodAssessment] = []) {
        self.primary = primary
        self.requiresConfirmation = requiresConfirmation
        self.excluded = excluded
    }
}

public struct FoodSelector: Sendable {
    public let policy: FoodEvidencePolicy

    public init(policy: FoodEvidencePolicy = FoodEvidencePolicy()) { self.policy = policy }

    public static func select(candidates: [FoodCandidate], request: FoodRequest, now: Date) -> FoodSelection {
        FoodSelector().select(candidates: candidates, request: request, now: now)
    }

    public func select(candidates: [FoodCandidate], request: FoodRequest, now: Date) -> FoodSelection {
        let assessments = candidates.map { assess($0, request: request, now: now) }
        // Resolve duplicate IDs conservatively before resolving identical dish/place pairs.
        let byID = deduplicate(assessments) { $0.candidate.id }
        let distinct = deduplicate(byID) {
            let place = $0.candidate.place
            // Saved observations intentionally have new local IDs. Collapse repeated
            // dish/place labels for display without treating labels as proof of identity.
            let label = place.map { FoodText.key($0.name) + "|" + FoodText.key($0.area) } ?? "home"
            return FoodText.key($0.candidate.dishName) + "|" + label
        }.sorted(by: precedes)
        let primary = Array(distinct.filter { $0.eligibility == .eligible }.prefix(3))
        let confirmation = Array(distinct.filter { $0.eligibility == .requiresConfirmation }
            .prefix(max(0, 3 - primary.count)))
        return FoodSelection(primary: primary, requiresConfirmation: confirmation,
                             excluded: distinct.filter { $0.eligibility == .excluded })
    }

    public func assess(_ candidate: FoodCandidate, request: FoodRequest, now: Date) -> FoodAssessment {
        let price = approvedPrice(candidate, now: now)
        let nutrition = approvedNutrition(candidate, now: now)
        let menu = approvedMenu(candidate, now: now)
        var excluded: [String] = []
        var uncertain: [String] = []
        if FoodText.key(candidate.id).isEmpty || FoodText.key(candidate.dishName).isEmpty {
            excluded.append("This food record has no usable identity.")
        }
        if !candidate.mealTypes.isEmpty && !candidate.mealTypes.contains(request.mealType) {
            excluded.append("This saved choice does not match the selected meal.")
        }
        let requestedArea = FoodText.key(request.area)
        if candidate.ingredients?.source.kind == .userSaved || candidate.price?.source.kind == .userSaved {
            if !requestedArea.isEmpty, let place = candidate.place,
               !FoodText.key(place.area).isEmpty, FoodText.key(place.area) != requestedArea {
                excluded.append("This saved dish belongs to a different area.")
            } else if candidate.place == nil || FoodText.key(candidate.place?.area ?? "").isEmpty {
                uncertain.append("The saved dish's area is not confirmed.")
            }
        }
        if candidate.requiredKitchen.capacity > request.kitchenAccess.capacity {
            excluded.append("This choice needs kitchen access you have not selected.")
        }
        let ingredients = candidate.ingredients?.value
        let ingredientWords = FoodText.keys(ingredients?.listedIngredients ?? [])
        let knownOtherAllergens = FoodText.keys(ingredients?.otherKnownAllergens ?? [])
        if let ingredients,
           request.allergens.contains(where: { ingredients.contains.contains($0) || ingredients.mayContain.contains($0) }) {
            excluded.append("A recorded ingredient conflicts with a selected allergen; do not choose this option.")
        }
        if request.allergens.contains(where: { allergen in
            positiveTerms(for: allergen).contains(where: { term in
                ingredientWords.contains(where: { mentions($0, term) })
            }) || knownOtherAllergens.contains(where: { note in
                allergyAliases(for: allergen).contains(where: { mentions(note, $0) })
            })
        }) {
            excluded.append("A recorded ingredient name matches a selected allergen; do not choose this option.")
        }
        if FoodText.keys(request.otherAllergies).contains(where: { allergy in
            knownOtherAllergens.contains(where: { mentions($0, allergy) })
                || ingredientWords.contains(where: { mentions($0, allergy) })
                || FoodAllergen.allCases.contains(where: { allergen in
                    allergyAliases(for: allergen).contains(where: { mentions(allergy, $0) })
                        && (ingredients?.contains.contains(allergen) == true
                            || ingredients?.mayContain.contains(allergen) == true
                            || knownOtherAllergens.contains(where: { note in
                                allergyAliases(for: allergen).contains(where: { mentions(note, $0) })
                            })
                            || positiveTerms(for: allergen).contains(where: { term in
                                ingredientWords.contains(where: { mentions($0, term) })
                            }))
                })
        }) {
            excluded.append("A recorded ingredient conflicts with your other allergy note; do not choose this option.")
        }
        let otherRuleKeys = FoodText.keys(request.otherDietaryRules)
        let explicitRules = request.dietaryRules + FoodDietaryRule.allCases.filter {
            otherRuleKeys.contains(FoodText.key($0.rawValue))
                || ($0 == .noPork && otherRuleKeys.contains("no pork"))
        }
        if dietaryConflict(explicitRules, ingredients: ingredients) {
            excluded.append("A recorded ingredient conflicts with a selected dietary rule.")
        }
        let dishKey = FoodText.key(candidate.dishName)
        if FoodText.keys(request.dislikes).contains(where: { dislike in
            mentions(dishKey, dislike) || ingredientWords.contains(where: { mentions($0, dislike) })
        }) {
            excluded.append("This choice includes a food you asked to avoid.")
        }
        if let maximum = request.maxPricePerMealSGD {
            if !maximum.isFinite || maximum < 0 {
                uncertain.append("Review the per-meal price preference before choosing.")
            } else if let price, price.value.amountSGD > maximum {
                excluded.append("The recorded per-item price exceeds your selected maximum; current price may differ.")
            } else if price == nil || price?.source.kind == .userSaved {
                uncertain.append("Current price within your per-meal maximum is not confirmed.")
            }
        }
        if !completeIngredients(candidate, request: request, now: now) {
            uncertain.append("Ingredients, dietary requirements, or allergen handling need confirmation with the food provider. Unknown does not mean suitable.")
        }
        if candidate.ingredients?.source.kind == .userSaved {
            uncertain.append("Ingredients saved from a prior visit are not current allergen or cross-contact assurance.")
        }
        let state: FoodEligibility = excluded.isEmpty
            ? (uncertain.isEmpty ? .eligible : .requiresConfirmation) : .excluded
        let reasons = excluded + uncertain + (state == .eligible
            ? ["Matched recent ingredient evidence covers the selected requirements. This is not a safety guarantee; confirm changes and cross-contact with the provider."] : [])
        return FoodAssessment(candidate: candidate, eligibility: state, reasons: reasons,
                              approvedPrice: price, approvedNutrition: nutrition, approvedMenu: menu)
    }

    private func completeIngredients(_ candidate: FoodCandidate, request: FoodRequest, now: Date) -> Bool {
        guard let evidence = candidate.ingredients,
              FoodProvenance.official(evidence.source, place: candidate.place),
              policy.isFresh(evidence, now: now, maxAge: policy.ingredientMaxAge),
              evidence.confidence == .high, evidence.uncertainty.isEmpty,
              evidence.value.isComplete, !FoodText.keys(evidence.value.listedIngredients).isEmpty else { return false }
        let value = evidence.value
        return request.allergens.allSatisfy { value.coveredAllergens.contains($0) }
            && request.dietaryRules.allSatisfy { value.compatibleDietaryRules.contains($0) }
            && FoodText.keys(request.otherAllergies).allSatisfy { FoodText.keys(value.coveredOtherAllergies).contains($0) }
            && FoodText.keys(request.otherDietaryRules).allSatisfy { FoodText.keys(value.coveredOtherDietaryRules).contains($0) }
    }

    private func approvedPrice(_ candidate: FoodCandidate, now: Date) -> FoodEvidence<FoodPrice>? {
        guard let evidence = candidate.price, evidence.value.isValid,
              policy.isFresh(evidence, now: now, maxAge: policy.priceMaxAge),
              !FoodText.key(evidence.source.title).isEmpty else { return nil }
        if FoodProvenance.official(evidence.source, place: candidate.place) { return evidence }
        if evidence.source.kind == .userSaved, let recordID = evidence.source.recordID,
           !FoodText.key(recordID).isEmpty { return evidence }
        return nil
    }

    private func approvedNutrition(_ candidate: FoodCandidate, now: Date) -> FoodEvidence<FoodNutritionEstimate>? {
        guard let evidence = candidate.nutrition, evidence.value.isValid,
              policy.isFresh(evidence, now: now, maxAge: policy.nutritionMaxAge),
              FoodText.key(evidence.value.matchedDishName) == FoodText.key(candidate.dishName),
              let serving = candidate.servingDescription,
              FoodText.key(serving) == FoodText.key(evidence.value.matchedServingDescription),
              FoodProvenance.foodID(evidence.source)
                || FoodProvenance.official(evidence.source, place: candidate.place) else { return nil }
        return evidence
    }

    private func approvedMenu(_ candidate: FoodCandidate, now: Date) -> FoodEvidence<URL>? {
        guard let evidence = candidate.officialMenu,
              policy.isFresh(evidence, now: now, maxAge: policy.menuMaxAge),
              FoodProvenance.official(evidence.source, place: candidate.place),
              evidence.value == evidence.source.url else { return nil }
        return evidence
    }

    private func mentions(_ text: String, _ term: String) -> Bool {
        let separators = CharacterSet.alphanumerics.inverted
        let words = text.components(separatedBy: separators).filter { !$0.isEmpty }.joined(separator: " ")
        let termWords = term.components(separatedBy: separators).filter { !$0.isEmpty }.joined(separator: " ")
        return !termWords.isEmpty && (" " + words + " ").contains(" " + termWords + " ")
    }

    /// Positive-name checks can add an exclusion; absence never grants coverage or suitability.
    private func positiveTerms(for allergen: FoodAllergen) -> [String] {
        switch allergen {
        case .peanuts: ["peanut", "peanuts", "groundnut", "groundnuts"]
        case .treeNuts: ["almond", "almonds", "cashew", "cashews", "walnut", "walnuts", "hazelnut", "pistachio", "pecan", "macadamia"]
        case .milk: ["milk", "butter", "cheese", "cream", "yogurt", "yoghurt", "whey", "casein"]
        case .egg: ["egg", "eggs"]
        case .fish: ["fish", "anchovy", "anchovies", "salmon", "tuna", "cod"]
        case .crustaceans: ["prawn", "prawns", "shrimp", "shrimps", "crab", "lobster", "crayfish"]
        case .molluscs: ["mussel", "mussels", "oyster", "oysters", "clam", "clams", "squid", "octopus", "scallop"]
        case .soy: ["soy", "soya", "soybean", "soybeans", "tofu", "tempeh"]
        case .wheat: ["wheat", "semolina", "spelt"]
        case .sesame: ["sesame", "tahini"]
        case .sulphites: ["sulphite", "sulphites", "sulfite", "sulfites"]
        }
    }

    private func allergyAliases(for allergen: FoodAllergen) -> [String] {
        let aliases: [String]
        switch allergen {
        case .peanuts: aliases = ["nuts"]
        case .treeNuts: aliases = ["tree nuts", "nuts"]
        case .milk: aliases = ["dairy", "lactose"]
        case .crustaceans, .molluscs: aliases = ["shellfish", "seafood"]
        case .fish: aliases = ["seafood"]
        case .wheat: aliases = ["gluten"]
        default: aliases = []
        }
        return aliases + [FoodText.key(allergen.rawValue)] + positiveTerms(for: allergen)
    }

    private func dietaryConflict(_ rules: [FoodDietaryRule], ingredients: FoodIngredients?) -> Bool {
        guard let ingredients else { return false }
        let words = FoodText.keys(ingredients.listedIngredients)
        let meat = ["pork", "bacon", "ham", "lard", "beef", "chicken", "duck", "lamb", "mutton", "gelatin", "gelatine"]
        let fishAndSeafood: [FoodAllergen] = [.fish, .crustaceans, .molluscs]
        func hasTerms(_ terms: [String]) -> Bool {
            terms.contains { term in words.contains { mentions($0, term) } }
        }
        func hasAllergen(_ allergens: [FoodAllergen]) -> Bool {
            allergens.contains { allergen in
                ingredients.contains.contains(allergen)
                    || FoodText.keys(ingredients.otherKnownAllergens).contains { note in
                        allergyAliases(for: allergen).contains { mentions(note, $0) }
                    }
                    || positiveTerms(for: allergen).contains { term in words.contains { mentions($0, term) } }
            }
        }
        if rules.contains(.noPork), hasTerms(["pork", "bacon", "ham", "lard"]) { return true }
        if rules.contains(.vegetarian) || rules.contains(.vegan) {
            if hasTerms(meat) || hasAllergen(fishAndSeafood) { return true }
        }
        if rules.contains(.vegan), hasAllergen([.milk, .egg]) || hasTerms(["honey"]) { return true }
        // A name cannot prove halal certification. Only explicit positive pork facts add an exclusion.
        if rules.contains(.halal), hasTerms(["pork", "bacon", "ham", "lard"]) { return true }
        return false
    }

    private func deduplicate(_ values: [FoodAssessment], key: (FoodAssessment) -> String) -> [FoodAssessment] {
        var result: [String: FoodAssessment] = [:]
        for value in values {
            let identity = key(value)
            if let prior = result[identity] {
                if restriction(value.eligibility) > restriction(prior.eligibility)
                    || (restriction(value.eligibility) == restriction(prior.eligibility) && precedes(value, prior)) {
                    result[identity] = value
                }
            } else { result[identity] = value }
        }
        return Array(result.values)
    }

    private func restriction(_ value: FoodEligibility) -> Int {
        switch value {
        case .eligible: 0
        case .requiresConfirmation: 1
        case .excluded: 2
        }
    }

    private func precedes(_ lhs: FoodAssessment, _ rhs: FoodAssessment) -> Bool {
        if (lhs.approvedPrice != nil) != (rhs.approvedPrice != nil) { return lhs.approvedPrice != nil }
        if let left = lhs.approvedPrice, let right = rhs.approvedPrice,
           left.value.amountSGD != right.value.amountSGD { return left.value.amountSGD < right.value.amountSGD }
        if lhs.candidate.id != rhs.candidate.id { return lhs.candidate.id < rhs.candidate.id }
        let leftName = FoodText.key(lhs.candidate.dishName)
        let rightName = FoodText.key(rhs.candidate.dishName)
        if leftName != rightName { return leftName < rightName }
        return fingerprint(lhs).lexicographicallyPrecedes(fingerprint(rhs))
    }

    /// Complete value ordering breaks duplicate ties without depending on input/dictionary order.
    private func fingerprint(_ value: FoodAssessment) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        return (try? encoder.encode(value)) ?? Data()
    }
}
