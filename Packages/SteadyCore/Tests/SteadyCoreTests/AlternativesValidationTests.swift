import Foundation
import Testing
@testable import SteadyCore

@Suite("Alternatives content and outcome validation")
struct AlternativesValidationTests {
    let outcome = Outcome(id: "movement", summary: "Keep movement", parts: [.gentleMovement])

    @Test("Only 2 or 3 primary options are accepted")
    func optionCount() {
        let option = alternativeOption("a", effort: .minimal)
        for options in [[AlternativeOption](), [option], [option, option, option, option]] {
            #expect(throws: AlternativeValidationError.invalidOptionCount) {
                try AlternativeValidator.validate(options, for: outcome)
            }
        }
    }

    @Test("Duplicate IDs and repeated effort cannot pad a set")
    func duplicateOrRepeatedEffort() {
        #expect(throws: AlternativeValidationError.duplicateOptionID) {
            try AlternativeValidator.validate([
                alternativeOption("same", effort: .minimal), alternativeOption("same", effort: .light)
            ], for: outcome)
        }
        #expect(throws: AlternativeValidationError.repeatedEffort) {
            try AlternativeValidator.validate([
                alternativeOption("a", effort: .minimal), alternativeOption("b", effort: .minimal)
            ], for: outcome)
        }
    }

    @Test("Changing only IDs and effort labels cannot duplicate the same option")
    func repeatedContent() {
        let original = alternativeOption("a", effort: .minimal)
        let duplicate = AlternativeOption(
            id: "b", title: original.title, minutes: original.minutes, effort: .light,
            benefitKept: original.benefitKept, tradeoff: original.tradeoff,
            preserves: original.preserves, doesNotPreserve: original.doesNotPreserve,
            steps: original.steps, planType: original.planType
        )
        #expect(throws: AlternativeValidationError.repeatedContent) {
            try AlternativeValidator.validate([original, duplicate], for: outcome)
        }
    }

    @Test("Outcome partitions cannot overlap or omit a part")
    func outcomePartition() {
        let good = alternativeOption("a", effort: .minimal)
        let overlap = alternativeOption("overlap", effort: .light, doesNotPreserve: [.gentleMovement])
        let omitted = alternativeOption("omitted", effort: .light, preserves: [])
        let extra = alternativeOption("extra", effort: .light, doesNotPreserve: [.sleepOpportunity])
        for bad in [overlap, omitted, extra] {
            #expect(throws: AlternativeValidationError.invalidOutcomePartition(bad.id)) {
                try AlternativeValidator.validate([good, bad], for: outcome)
            }
        }
    }

    @Test("Empty benefit, empty tradeoff, and zero duration are rejected")
    func requiredContent() {
        let good = alternativeOption("a", effort: .minimal)
        let badOptions = [
            alternativeOption("benefit", effort: .light, benefit: "  "),
            alternativeOption("tradeoff", effort: .light, tradeoff: ""),
            alternativeOption("duration", effort: .light, minutes: 0)
        ]
        for bad in badOptions {
            #expect(throws: AlternativeValidationError.invalidContent(bad.id)) {
                try AlternativeValidator.validate([good, bad], for: outcome)
            }
        }
    }

    @Test("A food outcome cannot be claimed by Phase 2 options")
    func noFoodClaims() {
        let meal = Outcome(id: "meal", summary: "Nourishment", parts: [.nourishment])
        #expect(throws: AlternativeValidationError.invalidContent("a")) {
            try AlternativeValidator.validate([
                alternativeOption("a", effort: .minimal, preserves: [.nourishment]),
                alternativeOption("b", effort: .light, preserves: [], doesNotPreserve: [.nourishment])
            ], for: meal)
        }
    }

    @Test("Catalog decoder rejects unsupported schema, duplicate templates, and inconsistent outcome partitions")
    func invalidCatalog() throws {
        let catalog = try alternativeCatalog()
        let first = try #require(catalog.templates.first)
        for malformed in [
            AlternativeCatalog(version: 2, templates: []),
            AlternativeCatalog(templates: [first, first]),
            AlternativeCatalog(templates: [AlternativeTemplate(id: "empty", planType: .walk, barriers: [], options: [])]),
            AlternativeCatalog(templates: [AlternativeTemplate(
                id: "inconsistent", planType: .walk, barriers: [.anotherOption], options: [
                    alternativeOption("a", effort: .minimal),
                    alternativeOption("b", effort: .light, preserves: [])
                ]
            )])
        ] {
            let data = try JSONEncoder().encode(malformed)
            #expect(throws: (any Error).self) { try AlternativeCatalogLoader.decode(data) }
        }
    }

    @Test("Invalid in-memory templates do not reach presentation")
    func invalidTemplateFallback() throws {
        let malformed = AlternativeTemplate(
            id: "bad", planType: .walk, barriers: [.anotherOption],
            options: [alternativeOption("bad", effort: .minimal)]
        )
        let engine = AlternativeEngine(catalog: AlternativeCatalog(templates: [malformed]))
        guard case .options(let set) = engine.alternatives(
            for: alternativePlan(), barrier: .anotherOption, context: AlternativeContext()
        ) else { Issue.record("Invalid catalog should use fallback"); return }
        #expect(set.source == .fallback)
        try AlternativeValidator.validate(set.options, for: outcome)
    }

    @Test("Production catalog round-trips without requiring legacy seed types")
    func codableRoundTrip() throws {
        let catalog = try alternativeCatalog()
        let decoded = try AlternativeCatalogLoader.decode(JSONEncoder().encode(catalog))
        #expect(decoded == catalog)
    }
}
