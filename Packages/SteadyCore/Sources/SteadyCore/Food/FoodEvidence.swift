import Foundation

public enum FoodSourceKind: String, Codable, Sendable {
    case mapKit, officialMenu, sgFoodID, userSaved, legacyFixture
}

public enum FoodConfidence: String, Codable, Sendable {
    case high, moderate, low
}

public struct FoodEvidenceSource: Codable, Equatable, Sendable {
    public let kind: FoodSourceKind
    public let title: String
    public let url: URL?
    public let recordID: String?
    /// Exact discovery identity, not merely a matching restaurant name.
    public let placeID: String?
    public let identityMatched: Bool

    public init(kind: FoodSourceKind, title: String, url: URL? = nil,
                recordID: String? = nil, placeID: String? = nil, identityMatched: Bool = false) {
        self.kind = kind
        self.title = title
        self.url = url
        self.recordID = recordID
        self.placeID = placeID
        self.identityMatched = identityMatched
    }
}

public struct FoodEvidence<Value: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    public let value: Value
    public let source: FoodEvidenceSource
    public let checkedAt: Date
    public let confidence: FoodConfidence
    public let uncertainty: [String]

    public init(value: Value, source: FoodEvidenceSource, checkedAt: Date,
                confidence: FoodConfidence, uncertainty: [String] = []) {
        self.value = value
        self.source = source
        self.checkedAt = checkedAt
        self.confidence = confidence
        self.uncertainty = uncertainty
    }
}

/// Conservative application freshness limits, not guarantees of current restaurant conditions.
public struct FoodEvidencePolicy: Codable, Equatable, Sendable {
    public let ingredientMaxAge: TimeInterval
    public let priceMaxAge: TimeInterval
    public let menuMaxAge: TimeInterval
    public let nutritionMaxAge: TimeInterval

    public init(ingredientMaxAge: TimeInterval = 86_400, priceMaxAge: TimeInterval = 2_592_000,
                menuMaxAge: TimeInterval = 604_800, nutritionMaxAge: TimeInterval = 31_536_000) {
        self.ingredientMaxAge = ingredientMaxAge
        self.priceMaxAge = priceMaxAge
        self.menuMaxAge = menuMaxAge
        self.nutritionMaxAge = nutritionMaxAge
    }

    func isFresh<Value: Codable & Equatable & Sendable>(
        _ evidence: FoodEvidence<Value>, now: Date, maxAge: TimeInterval
    ) -> Bool {
        let age = now.timeIntervalSince(evidence.checkedAt)
        return evidence.checkedAt.timeIntervalSinceReferenceDate.isFinite
            && now.timeIntervalSinceReferenceDate.isFinite && maxAge.isFinite
            && maxAge >= 0 && age >= 0 && age <= maxAge
    }
}

enum FoodProvenance {
    static func webURL(_ url: URL?) -> Bool {
        guard let url, url.scheme?.lowercased() == "https", let host = url.host,
              !host.isEmpty, url.user == nil, url.password == nil else { return false }
        return true
    }

    static func official(_ source: FoodEvidenceSource, place: FoodPlace?) -> Bool {
        guard source.kind == .officialMenu, !FoodText.key(source.title).isEmpty,
              webURL(source.url), let place, !FoodText.key(place.id).isEmpty,
              source.placeID == place.id, source.identityMatched,
              webURL(place.websiteURL),
              source.url?.host?.lowercased() == place.websiteURL?.host?.lowercased() else { return false }
        return true
    }

    static func foodID(_ source: FoodEvidenceSource) -> Bool {
        guard source.kind == .sgFoodID, webURL(source.url),
              let host = source.url?.host?.lowercased(),
              host == "hpb.gov.sg" || host.hasSuffix(".hpb.gov.sg"),
              let recordID = source.recordID, !FoodText.key(recordID).isEmpty,
              !FoodText.key(source.title).isEmpty else { return false }
        return true
    }
}
