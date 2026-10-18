import Foundation

public struct FoodCorrectionDraft: Codable, Equatable, Sendable {
    /// A locally generated dish identity; callers must not pass coordinate-bearing discovery IDs.
    public let candidateID: String
    public let dishName: String
    public let place: FoodPlace?
    public let mealTypes: [FoodMealType]
    public let requiredKitchen: FoodKitchenAccess
    public let observedAt: Date
    public let priceSGD: Double?
    public let portion: String
    public let ingredientNotes: [String]
    public let knownAllergens: [FoodAllergen]
    public let otherKnownAllergens: [String]

    public init(candidateID: String, dishName: String, place: FoodPlace? = nil,
                mealTypes: [FoodMealType] = [], requiredKitchen: FoodKitchenAccess = .none,
                observedAt: Date, priceSGD: Double? = nil, portion: String = "per dish",
                ingredientNotes: [String] = [], knownAllergens: [FoodAllergen] = [],
                otherKnownAllergens: [String] = []) {
        self.candidateID = candidateID
        self.dishName = dishName
        self.place = place
        self.mealTypes = mealTypes
        self.requiredKitchen = requiredKitchen
        self.observedAt = observedAt
        self.priceSGD = priceSGD
        self.portion = portion
        self.ingredientNotes = ingredientNotes
        self.knownAllergens = knownAllergens
        self.otherKnownAllergens = otherKnownAllergens
    }
}

public struct FoodCorrectionProposal: Codable, Equatable, Sendable {
    public let id: UUID
    public let profileID: UUID
    public let isSample: Bool
    public let createdAt: Date
    public let draft: FoodCorrectionDraft

    public init(id: UUID, profileID: UUID, isSample: Bool, createdAt: Date, draft: FoodCorrectionDraft) {
        self.id = id
        self.profileID = profileID
        self.isSample = isSample
        self.createdAt = createdAt
        self.draft = draft
    }
}

public struct FoodSavedCorrection: Codable, Equatable, Sendable {
    public let id: UUID
    public let candidate: FoodCandidate
    public let confirmedAt: Date

    public init(id: UUID, candidate: FoodCandidate, confirmedAt: Date) {
        self.id = id
        self.candidate = candidate
        self.confirmedAt = confirmedAt
    }
}

/// Proposals are inert values. Only the app's explicit confirmation action calls confirm.
public enum FoodCorrectionReducer {
    public static func propose(draft: FoodCorrectionDraft, remember: Bool, profileID: UUID,
                               isSample: Bool, now: Date, operationID: UUID) -> FoodCorrectionProposal? {
        guard remember, valid(draft, now: now) else { return nil }
        return FoodCorrectionProposal(id: operationID, profileID: profileID, isSample: isSample,
                                      createdAt: now, draft: draft)
    }

    public static func confirm(proposal: FoodCorrectionProposal, profileID: UUID, isSample: Bool,
                               now: Date, existing: [FoodSavedCorrection] = []) -> FoodSavedCorrection? {
        let age = now.timeIntervalSince(proposal.createdAt)
        guard proposal.profileID == profileID, proposal.isSample == isSample,
              proposal.createdAt.timeIntervalSinceReferenceDate.isFinite,
              now.timeIntervalSinceReferenceDate.isFinite,
              age >= 0, age <= 900, valid(proposal.draft, now: now) else { return nil }
        let draft = proposal.draft
        // Discovery coordinates, directory identity, and website are not retained with a saved dish.
        let savedPlace = draft.place.map {
            FoodPlace(id: "saved-place:" + proposal.id.uuidString,
                      name: $0.name, area: $0.area, checkedAt: draft.observedAt)
        }
        let source = FoodEvidenceSource(kind: .userSaved, title: "Saved from prior visit",
                                        recordID: proposal.id.uuidString, placeID: savedPlace?.id)
        let ingredients = FoodEvidence(value: FoodIngredients(listedIngredients: draft.ingredientNotes,
            contains: draft.knownAllergens, otherKnownAllergens: draft.otherKnownAllergens),
            source: source, checkedAt: draft.observedAt, confidence: .low,
            uncertainty: ["Prior-visit observation only; ingredients and cross-contact may change."])
        let price = draft.priceSGD.map {
            FoodEvidence(value: FoodPrice(amountSGD: $0, portion: draft.portion), source: source,
                         checkedAt: draft.observedAt, confidence: .low,
                         uncertainty: ["Saved from a prior visit; current price may differ."])
        }
        let candidate = FoodCandidate(id: draft.candidateID, dishName: draft.dishName,
            place: savedPlace, mealTypes: draft.mealTypes, servingDescription: draft.portion,
            requiredKitchen: draft.requiredKitchen, ingredients: ingredients, price: price)
        if let prior = existing.first(where: { $0.id == proposal.id }) {
            return prior.candidate == candidate ? prior : nil
        }
        return FoodSavedCorrection(id: proposal.id, candidate: candidate, confirmedAt: now)
    }

    private static func valid(_ draft: FoodCorrectionDraft, now: Date) -> Bool {
        guard now.timeIntervalSinceReferenceDate.isFinite,
              draft.observedAt.timeIntervalSinceReferenceDate.isFinite,
              draft.observedAt <= now, !FoodText.key(draft.candidateID).isEmpty,
              !FoodText.key(draft.dishName).isEmpty, !FoodText.key(draft.portion).isEmpty,
              draft.dishName.count <= 200, draft.candidateID.count <= 500,
              draft.portion.count <= 200, draft.ingredientNotes.count <= 100,
              draft.ingredientNotes.allSatisfy({ $0.count <= 500 }),
              draft.otherKnownAllergens.count <= 50,
              draft.otherKnownAllergens.allSatisfy({ $0.count <= 200 }) else { return false }
        if let place = draft.place {
            guard !FoodText.key(place.id).isEmpty, !FoodText.key(place.name).isEmpty,
                  !FoodText.key(place.area).isEmpty, place.id.count <= 500,
                  place.name.count <= 200, place.area.count <= 200 else { return false }
        }
        if let price = draft.priceSGD { return price.isFinite && price >= 0 }
        return true
    }
}
