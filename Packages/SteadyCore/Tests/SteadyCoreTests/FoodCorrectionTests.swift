import Foundation
import Testing
@testable import SteadyCore

@Test func foodRememberFalseDoesNotCreateProposal() {
    #expect(FoodCorrectionReducer.propose(draft: foodDraft(), remember: false, profileID: UUID(),
        isSample: false, now: foodDate(), operationID: UUID()) == nil)
}

@Test func foodProposalIsInertAndDeterministicUntilExplicitConfirm() throws {
    let profile = UUID()
    let operation = UUID()
    let proposal = FoodCorrectionReducer.propose(draft: foodDraft(), remember: true, profileID: profile,
        isSample: false, now: foodDate(), operationID: operation)
    #expect(proposal?.id == operation)
    #expect(proposal == FoodCorrectionReducer.propose(draft: foodDraft(), remember: true, profileID: profile,
        isSample: false, now: foodDate(), operationID: operation))
    let data = try JSONEncoder().encode(proposal)
    #expect(try JSONDecoder().decode(FoodCorrectionProposal?.self, from: data) == proposal)
    // Merely encoding, discarding, or cancelling this value yields no saved candidate.
}

@Test func foodCorrectionRejectsProfileSampleFutureAndExpiredConfirm() {
    let proposal = foodProposal()
    #expect(FoodCorrectionReducer.confirm(proposal: proposal, profileID: UUID(), isSample: false, now: foodDate()) == nil)
    #expect(FoodCorrectionReducer.confirm(proposal: proposal, profileID: proposal.profileID, isSample: true, now: foodDate()) == nil)
    #expect(FoodCorrectionReducer.confirm(proposal: proposal, profileID: proposal.profileID, isSample: false,
        now: foodDate().addingTimeInterval(-1)) == nil)
    #expect(FoodCorrectionReducer.confirm(proposal: proposal, profileID: proposal.profileID, isSample: false,
        now: foodDate().addingTimeInterval(901)) == nil)
}

@Test func foodFutureObservationAndInvalidDraftDoNotPropose() {
    let drafts = [foodDraft(observedAt: foodDate().addingTimeInterval(1)), foodDraft(price: -1),
                  foodDraft(price: .nan), foodDraft(dishName: " ")]
    for draft in drafts {
        #expect(FoodCorrectionReducer.propose(draft: draft, remember: true, profileID: UUID(),
            isSample: false, now: foodDate(), operationID: UUID()) == nil)
    }
}

@Test func foodInvalidPlaceCannotBeRemembered() {
    let draft = FoodCorrectionDraft(candidateID: "local-dish", dishName: "Rice",
        place: FoodPlace(id: "", name: "Venue", area: "Campus", checkedAt: foodDate()), observedAt: foodDate())
    #expect(FoodCorrectionReducer.propose(draft: draft, remember: true, profileID: UUID(),
        isSample: false, now: foodDate(), operationID: UUID()) == nil)
}

@Test func foodConfirmedCorrectionRetainsOnlyMinimalPriorVisitFacts() {
    let proposal = foodProposal()
    let saved = FoodCorrectionReducer.confirm(proposal: proposal, profileID: proposal.profileID,
                                              isSample: false, now: foodDate())!
    #expect(saved.candidate.place?.coordinate == nil)
    #expect(saved.candidate.place?.websiteURL == nil)
    #expect(saved.candidate.place?.id != proposal.draft.place?.id)
    #expect(saved.candidate.officialMenu == nil)
    #expect(saved.candidate.nutrition == nil)
    #expect(saved.candidate.ingredients?.value.isComplete == false)
    #expect(saved.candidate.ingredients?.source.kind == .userSaved)
    #expect(saved.candidate.ingredients?.source.placeID == saved.candidate.place?.id)
    #expect(saved.candidate.price?.source.placeID == saved.candidate.place?.id)
    #expect(saved.candidate.price?.checkedAt == proposal.draft.observedAt)
}

@Test func foodCorrectionConfirmationIsIdempotent() {
    let proposal = foodProposal()
    let saved = FoodCorrectionReducer.confirm(proposal: proposal, profileID: proposal.profileID,
                                              isSample: false, now: foodDate())!
    let replay = FoodCorrectionReducer.confirm(proposal: proposal, profileID: proposal.profileID,
        isSample: false, now: foodDate().addingTimeInterval(60), existing: [saved])
    #expect(replay == saved)
}

@Test func foodSameOperationWithReplacedFactsIsRejected() {
    let proposal = foodProposal()
    let saved = FoodCorrectionReducer.confirm(proposal: proposal, profileID: proposal.profileID,
                                              isSample: false, now: foodDate())!
    let replaced = FoodCorrectionProposal(id: proposal.id, profileID: proposal.profileID,
        isSample: false, createdAt: proposal.createdAt, draft: foodDraft(price: 99))
    #expect(FoodCorrectionReducer.confirm(proposal: replaced, profileID: proposal.profileID,
        isSample: false, now: foodDate(), existing: [saved]) == nil)
}

@Test func foodSavedKnownAllergenRemainsExcludedAcrossRoundTrip() throws {
    let draft = FoodCorrectionDraft(candidateID: "local-dish", dishName: "Remembered rice",
        place: foodPlace(), mealTypes: [.lunch], observedAt: foodDate(), knownAllergens: [.milk])
    let proposal = foodProposal(draft: draft)
    let saved = FoodCorrectionReducer.confirm(proposal: proposal, profileID: proposal.profileID,
                                              isSample: false, now: foodDate())!
    let decoded = try JSONDecoder().decode(FoodSavedCorrection.self, from: JSONEncoder().encode(saved))
    #expect(foodAssessment(decoded.candidate, request: foodRequest(allergens: [.milk])).eligibility == .excluded)
}

@Test func foodConfirmedPriceAffectsOrderingOnlyAfterConfirm() {
    let proposal = foodProposal()
    let unknown = foodCandidate("unknown", ingredients: nil, dishName: "Unknown rice")
    let before = FoodSelector.select(candidates: [unknown], request: foodRequest(), now: foodDate())
    #expect(before.requiresConfirmation.first?.approvedPrice == nil)
    let saved = FoodCorrectionReducer.confirm(proposal: proposal, profileID: proposal.profileID,
                                              isSample: false, now: foodDate())!
    let after = FoodSelector.select(candidates: [unknown, saved.candidate], request: foodRequest(), now: foodDate())
    #expect(after.requiresConfirmation.first?.candidate.id == saved.candidate.id)
    #expect(after.primary.isEmpty)
}
