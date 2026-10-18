import Foundation
import SteadyCore
import SwiftData

/// Only an explicitly confirmed observation enters this table, never a nearby search.
@Model
final class FoodCorrectionRecord {
    @Attribute(.unique) var key: String
    var profileID: UUID
    var sampleData: Bool
    var correctionData: Data
    var updatedAt: Date

    init(key: String, profileID: UUID, sampleData: Bool, correction: FoodSavedCorrection, at: Date) throws {
        self.key = key
        self.profileID = profileID
        self.sampleData = sampleData
        self.correctionData = try JSONEncoder().encode(correction)
        self.updatedAt = at
    }
}
