import Foundation
import SwiftData
import SteadyCore

struct SavedChoice: Codable, Sendable {
    let id: String
    let planID: String
    let at: Date
    let action: String
    let barrier: AlternativeBarrier?
    let optionID: String?
}

@Model
final class ChoiceRecord {
    @Attribute(.unique) var id: String
    var profileID: UUID
    var sampleData: Bool
    var at: Date
    var choiceData: Data

    init(choice: SavedChoice, profileID: UUID, sampleData: Bool) throws {
        self.id = choice.id
        self.profileID = profileID
        self.sampleData = sampleData
        self.at = choice.at
        self.choiceData = try JSONEncoder().encode(choice)
    }
}
