import Foundation
import SteadyCore
import SwiftData

/// A reviewed week stores only the explicit response, never a copy of Health context.
@Model
final class WeeklyReviewRecord {
    @Attribute(.unique) var key: String
    var profileID: UUID
    var sampleData: Bool
    var weekStart: Date
    var reviewData: Data
    var updatedAt: Date

    init(key: String, review: WeeklyReview, at: Date) throws {
        self.key = key
        self.profileID = review.scope.profileID
        self.sampleData = review.scope.isSample
        self.weekStart = review.scope.weekStart
        self.reviewData = try JSONEncoder().encode(review)
        self.updatedAt = at
    }
}

/// One explicitly confirmed, bounded local experiment; it changes no plan or default.
@Model
final class WeeklyExperimentRecord {
    @Attribute(.unique) var key: String
    var profileID: UUID
    var sampleData: Bool
    var weekStart: Date
    var experimentData: Data
    var updatedAt: Date

    init(key: String, experiment: WeeklyExperiment, at: Date) throws {
        self.key = key
        self.profileID = experiment.scope.profileID
        self.sampleData = experiment.scope.isSample
        self.weekStart = experiment.scope.weekStart
        self.experimentData = try JSONEncoder().encode(experiment)
        self.updatedAt = at
    }
}

/// Local typed evaluation events only, with no content, Health values, or analytics transport.
@Model
final class WeeklyMetricRecord {
    @Attribute(.unique) var id: String
    var profileID: UUID
    var sampleData: Bool
    var at: Date
    var eventData: Data

    init(event: WeeklyMetricEvent, profileID: UUID, sampleData: Bool) throws {
        self.id = event.id
        self.profileID = profileID
        self.sampleData = sampleData
        self.at = event.at
        self.eventData = try JSONEncoder().encode(event)
    }
}
