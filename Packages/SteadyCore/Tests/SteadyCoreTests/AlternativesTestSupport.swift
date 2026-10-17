import Foundation
@testable import SteadyCore

func alternativePlan(_ type: PlanType = .walk, parts: Set<OutcomePart> = [.gentleMovement], minutes: Int = 30) -> PlanItem {
    PlanItem(
        id: "alternative-plan", day: testDate(), type: type, title: "Original plan",
        outcome: Outcome(id: "original", summary: "Original outcome", parts: parts),
        minutes: minutes, slot: nil, origin: .user
    )
}

func alternativeCatalog() throws -> AlternativeCatalog {
    guard let url = Bundle.module.url(forResource: "plan-alternatives", withExtension: "json") else {
        throw CocoaError(.fileNoSuchFile)
    }
    return try AlternativeCatalogLoader.decode(Data(contentsOf: url))
}

func alternativeOption(
    _ id: String, effort: AlternativeEffort,
    preserves: Set<OutcomePart> = [.gentleMovement],
    doesNotPreserve: Set<OutcomePart> = [],
    benefit: String = "Keeps comfortable movement", tradeoff: String = "Less time than the original plan",
    minutes: Int = 5
) -> AlternativeOption {
    AlternativeOption(
        id: id, title: "Comfortable movement: \(id)", minutes: minutes, effort: effort,
        benefitKept: benefit, tradeoff: tradeoff, preserves: preserves,
        doesNotPreserve: doesNotPreserve, steps: ["Use a familiar comfortable movement."], planType: .mobility
    )
}
