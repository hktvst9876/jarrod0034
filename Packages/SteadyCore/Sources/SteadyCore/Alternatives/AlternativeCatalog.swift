import Foundation

public struct AlternativeTemplate: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let planType: PlanType
    public let barriers: Set<AlternativeBarrier>
    public let options: [AlternativeOption]

    public init(id: String, planType: PlanType, barriers: Set<AlternativeBarrier>, options: [AlternativeOption]) {
        self.id = id
        self.planType = planType
        self.barriers = barriers
        self.options = options
    }
}

public struct AlternativeCatalog: Codable, Equatable, Sendable {
    public let version: Int
    public let templates: [AlternativeTemplate]

    public init(version: Int = 1, templates: [AlternativeTemplate]) {
        self.version = version
        self.templates = templates
    }

    public static let empty = AlternativeCatalog(templates: [])
}

public enum AlternativeValidationError: Error, Equatable, Sendable {
    case unsupportedVersion
    case invalidTemplate(String)
    case invalidOptionCount
    case duplicateOptionID
    case repeatedEffort
    case repeatedContent
    case invalidContent(String)
    case invalidOutcomePartition(String)
}

public enum AlternativeValidator {
    public static func validate(_ options: [AlternativeOption], for outcome: Outcome) throws {
        guard (2...3).contains(options.count) else {
            throw AlternativeValidationError.invalidOptionCount
        }
        guard Set(options.map(\.id)).count == options.count else {
            throw AlternativeValidationError.duplicateOptionID
        }
        guard Set(options.map(\.effort)).count == options.count else {
            throw AlternativeValidationError.repeatedEffort
        }
        let content = options.map { $0.title + "|" + $0.steps.joined(separator: "|") }
        guard Set(content).count == options.count else {
            throw AlternativeValidationError.repeatedContent
        }
        for option in options {
            let text = [option.id, option.title, option.benefitKept, option.tradeoff] + option.steps
            guard option.minutes > 0, !option.steps.isEmpty,
                  !option.supportedMovementModes.isEmpty,
                  text.allSatisfy({ !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
                throw AlternativeValidationError.invalidContent(option.id)
            }
            guard option.preserves.isDisjoint(with: option.doesNotPreserve),
                  option.preserves.union(option.doesNotPreserve) == outcome.parts else {
                throw AlternativeValidationError.invalidOutcomePartition(option.id)
            }
            // Food evidence belongs to Phase 5. A pause, preparation step, or
            // movement option cannot claim it provides nourishment.
            guard !option.preserves.contains(.nourishment) else {
                throw AlternativeValidationError.invalidContent(option.id)
            }
        }
    }
}

/// This is the production catalog. The old `alternatives.json` remains a legacy
/// fixture; its prices and outcome claims must not be promoted into this catalog.
public enum AlternativeCatalogLoader {
    public static func decode(_ data: Data) throws -> AlternativeCatalog {
        let catalog = try JSONDecoder().decode(AlternativeCatalog.self, from: data)
        guard catalog.version == 1 else { throw AlternativeValidationError.unsupportedVersion }
        var seenIDs: Set<String> = []
        for template in catalog.templates {
            guard !template.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  seenIDs.insert(template.id).inserted, !template.barriers.isEmpty,
                  let first = template.options.first else {
                throw AlternativeValidationError.invalidTemplate(template.id)
            }
            let outcome = Outcome(
                id: template.id,
                summary: "Catalog outcome partition",
                parts: first.preserves.union(first.doesNotPreserve)
            )
            try AlternativeValidator.validate(template.options, for: outcome)
        }
        return catalog
    }
}
