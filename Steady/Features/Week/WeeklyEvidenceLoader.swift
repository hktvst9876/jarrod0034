import CryptoKit
import Foundation
import SteadyCore
import SwiftData

struct WeeklyStoredEvidence {
    let scope: WeeklyScope
    let plans: [WeeklyPlanObservation]
    let choices: [WeeklyChoiceObservation]
    let foundations: [WeeklyFoundationObservation]
    let movement: [WeeklyMovementObservation]
    let foods: [WeeklyFoodCorrectionObservation]
    let metrics: [WeeklyMetricEvent]
    let review: WeeklyReview?
    let experiment: WeeklyExperiment?
}

/// Fresh, profile-scoped reads. Runtime Health samples never enter this store or its revision.
@MainActor
enum WeeklyEvidenceLoader {
    static func key(profileID: UUID, sample: Bool, week: Date) -> String {
        "\(profileID.uuidString)-\(sample)-\(Int(week.timeIntervalSinceReferenceDate))"
    }

    static func read(profile: ProfileRecord, sample: Bool, window: WeeklyWindow,
                     container: ModelContainer) throws -> WeeklyStoredEvidence {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let id = profile.id
        guard let persistedProfile = try context.fetch(FetchDescriptor<ProfileRecord>(predicate: #Predicate { $0.id == id })).first,
              persistedProfile.domainProfile() == profile.domainProfile(),
              persistedProfile.movementsToAvoid == profile.movementsToAvoid,
              persistedProfile.dietaryRulesText == profile.dietaryRulesText,
              persistedProfile.allergiesText == profile.allergiesText,
              persistedProfile.maxPricePerMealSGD == profile.maxPricePerMealSGD else { throw WeeklyReadError.staleContext }
        let plans = try context.fetch(FetchDescriptor<PlanRecord>(predicate: #Predicate { $0.profileID == id && $0.sampleData == sample }))
        let choices = try context.fetch(FetchDescriptor<ChoiceRecord>(predicate: #Predicate { $0.profileID == id && $0.sampleData == sample }))
        let days = try context.fetch(FetchDescriptor<FoundationDayRecord>(predicate: #Predicate { $0.profileID == id && $0.sampleData == sample }))
        let responses = try context.fetch(FetchDescriptor<FoundationResponseRecord>(predicate: #Predicate { $0.profileID == id && $0.sampleData == sample }))
        let preferences = try context.fetch(FetchDescriptor<FoundationPreferenceRecord>(predicate: #Predicate { $0.profileID == id && $0.sampleData == sample }))
        let movements = try context.fetch(FetchDescriptor<WatchMovementRecord>(predicate: #Predicate { $0.profileID == id && $0.sampleData == sample }))
        let foods = try context.fetch(FetchDescriptor<FoodCorrectionRecord>(predicate: #Predicate { $0.profileID == id && $0.sampleData == sample }))
        let metrics = try context.fetch(FetchDescriptor<WeeklyMetricRecord>(predicate: #Predicate { $0.profileID == id && $0.sampleData == sample }))
        let reviews = try context.fetch(FetchDescriptor<WeeklyReviewRecord>(predicate: #Predicate { $0.profileID == id && $0.sampleData == sample }))
        let experiments = try context.fetch(FetchDescriptor<WeeklyExperimentRecord>(predicate: #Predicate { $0.profileID == id && $0.sampleData == sample }))
        var versions: [String] = []
        func remember(_ category: String, _ key: String, _ data: Data) {
            versions.append(category + ":" + key + ":" + data.base64EncodedString())
        }
        // Exact saved bytes, not a random refresh ID, invalidate open consequential proposals.
        for row in plans { remember("plan", row.key, row.planData + row.originalPlanData); versions.append("plan-meta:\(row.key):\(row.updatedAt.timeIntervalSinceReferenceDate):\(row.supersededByKey ?? "")") }
        for row in choices { remember("choice", row.id, row.choiceData) }
        for row in days { remember("foundation", row.key, row.stateData) }
        for row in responses { versions.append("response:\(row.id):\(row.day.timeIntervalSinceReferenceDate):\(row.kindRawValue):\(row.action)") }
        for row in preferences {
            remember("foundation-preference", row.key, row.settingsData + row.quietPeriodsData + row.dismissalCountsData + row.reservationsData)
            versions.append("foundation-preference-meta:\(row.key):\(row.nudgesEnabled):\(row.updatedAt.timeIntervalSinceReferenceDate)")
        }
        for row in movements { versions.append("movement:\(row.id):\(row.day.timeIntervalSinceReferenceDate):\(row.minutes):\(row.observedAt.timeIntervalSinceReferenceDate)") }
        for row in foods { remember("food", row.key, row.correctionData) }
        for row in metrics { remember("metric", row.id, row.eventData) }
        for row in reviews { remember("review", row.key, row.reviewData) }
        for row in experiments { remember("experiment", row.key, row.experimentData) }
        let profileEncoder = JSONEncoder()
        profileEncoder.outputFormatting = [.sortedKeys]
        remember("profile", id.uuidString, try profileEncoder.encode(profile.domainProfile()))
        versions.append("profile-notes:\(profile.movementsToAvoid):\(profile.dietaryRulesText):\(profile.allergiesText):\(profile.maxPricePerMealSGD.map { String($0) } ?? "")")
        let digest = SHA256.hash(data: Data(versions.sorted().joined(separator: "\n").utf8))
        let revision = digest.map { String(format: "%02x", $0) }.joined()
        let scope = WeeklyScope(profileID: id, isSample: sample, weekStart: window.start, revision: revision)
        let decodedChoices = try choices.map { try JSONDecoder().decode(SavedChoice.self, from: $0.choiceData) }
        let choiceValues = decodedChoices.compactMap { value -> WeeklyChoiceObservation? in
            guard let kind = WeeklyChoiceKind(rawValue: value.action) else { return nil }
            return WeeklyChoiceObservation(id: value.id, at: value.at, planID: value.planID, kind: kind, optionID: value.optionID)
        }
        let planValues = try plans.filter { $0.supersededByKey == nil && window.contains($0.day) }.map { row in
            let value = try row.plan()
            let original = try row.originalPlan()
            let changed = value.type != original.type || value.title != original.title || value.minutes != original.minutes
                || decodedChoices.contains { $0.planID == value.id && ["choose", "later", "rest", "schedule"].contains($0.action) && window.contains($0.at) }
            return WeeklyPlanObservation(id: value.id, day: row.day, completed: value.status == .completed, changed: changed)
        }
        var foundationValues: [String: WeeklyFoundationObservation] = [:]
        for row in days where window.contains(row.day) {
            let state = try JSONDecoder().decode(FoundationDayState.self, from: row.stateData)
            for item in state.items {
                let key = "\(row.day.timeIntervalSinceReferenceDate)-\(item.kind.rawValue)"
                let dismissed = responses.contains { $0.day == row.day && $0.kindRawValue == item.kind.rawValue && $0.action == "dismiss" }
                foundationValues[key] = WeeklyFoundationObservation(id: key, day: row.day, kind: item.kind,
                    done: item.status == .done, dismissed: dismissed)
            }
        }
        for row in responses where row.action == "dismiss" && window.contains(row.day) {
            guard let kind = FoundationKind(rawValue: row.kindRawValue) else { throw WeeklyReadError.invalidRecord }
            let key = "\(row.day.timeIntervalSinceReferenceDate)-\(kind.rawValue)"
            if foundationValues[key] == nil {
                foundationValues[key] = WeeklyFoundationObservation(id: key, day: row.day, kind: kind, done: false, dismissed: true)
            }
        }
        let foodValues = try foods.map { row in
            let value = try JSONDecoder().decode(FoodSavedCorrection.self, from: row.correctionData)
            return WeeklyFoodCorrectionObservation(id: value.id.uuidString, at: value.confirmedAt,
                savedDishID: value.candidate.id, dishName: value.candidate.dishName)
        }
        let metricValues = try metrics.map { try JSONDecoder().decode(WeeklyMetricEvent.self, from: $0.eventData) }
        let reviewValues = try reviews.map { try JSONDecoder().decode(WeeklyReview.self, from: $0.reviewData) }
        let experimentValues = try experiments.map { try JSONDecoder().decode(WeeklyExperiment.self, from: $0.experimentData) }
        guard reviewValues.allSatisfy({ $0.scope.profileID == id && $0.scope.isSample == sample }),
              experimentValues.allSatisfy({ $0.scope.profileID == id && $0.scope.isSample == sample }) else { throw WeeklyReadError.invalidRecord }
        return WeeklyStoredEvidence(scope: scope, plans: planValues, choices: choiceValues,
            foundations: Array(foundationValues.values), movement: movements.map {
                WeeklyMovementObservation(id: $0.id, at: $0.observedAt, minutes: $0.minutes, source: .userReported)
            }, foods: foodValues, metrics: metricValues,
            review: reviewValues.filter { $0.scope.weekStart == window.start }.max { $0.reviewedAt < $1.reviewedAt },
            experiment: experimentValues.max { $0.endExclusive < $1.endExclusive })
    }
}

enum WeeklyReadError: Error { case invalidRecord, staleContext }
