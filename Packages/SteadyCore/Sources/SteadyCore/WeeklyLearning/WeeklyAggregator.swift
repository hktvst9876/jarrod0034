import Foundation

public struct WeeklyFoodFrequency: Codable, Equatable, Sendable {
    public let dishID: String
    public let name: String
    public let count: Int
}

/// Observation counts describe retained local records, not everything a person did.
public struct WeeklySummary: Codable, Equatable, Sendable {
    public let scope: WeeklyScope
    public let window: WeeklyWindow
    public let actualSleepMinutes: Double?
    public let sleepOpportunityMinutes: Double?
    public let sleepTrackedDays: Int
    public let opportunityTrackedDays: Int
    public let movementMinutes: Int?
    public let movementEntries: Int
    public let healthMovementEntries: Int
    public let userReportedMovementEntries: Int
    public let sampleMovementEntries: Int
    public let plansRecorded: Int
    public let plansCompleted: Int
    public let plansChanged: Int
    public let changedPlanDays: Int
    public let evidenceChangedPlanIDs: [String]
    public let alternativesChosen: Int
    public let alternativesCompleted: Int
    public let foundationsRecorded: Int
    public let foundationsDone: Int
    public let foundationsDismissed: Int
    public let foodCorrections: Int
    public let commonSavedFoods: [WeeklyFoodFrequency]
    public let metrics: WeeklyMetricSummary
}

public enum WeeklyAggregator {
    public static func summarize(_ input: WeeklyInput, calendar: Calendar = SteadyCalendar.singapore()) -> WeeklySummary {
        let window = input.window
        let sleep = unambiguous(input.sleep, id: { $0.id }).filter {
            window.contains($0.day) && sourceAllowed($0.source, scope: input.scope)
        }
        let nights = Dictionary(grouping: sleep, by: { calendar.startOfDay(for: $0.day) })
        let actual = nights.values.compactMap { value($0, select: { $0.actualMinutes }) }
        let opportunity = nights.values.compactMap { value($0, select: { $0.opportunityMinutes }) }
        let movement = unambiguous(input.movement, id: { $0.id }).filter {
            window.contains($0.at) && (0...1_440).contains($0.minutes) && sourceAllowed($0.source, scope: input.scope)
        }
        let plans = unambiguous(input.plans, id: { $0.id }).filter { window.contains($0.day) }
        let choices = unambiguous(input.choices, id: { $0.id }).filter {
            window.contains($0.at) && !$0.planID.isEmpty
        }
        let chosen = choices.filter { $0.kind == .choose && !($0.optionID ?? "").isEmpty }
        let completedAlternativePlans = Set(choices.filter { completion in
            guard completion.kind == .complete,
                  let latestChoice = chosen.filter({ $0.planID == completion.planID && $0.at <= completion.at })
                    .sorted(by: { $0.at == $1.at ? $0.id < $1.id : $0.at > $1.at }).first else { return false }
            return completion.optionID == nil || latestChoice.optionID == completion.optionID
        }.map(\.planID))
        let changedIDs = Set(plans.filter(\.changed).map(\.id)).union(choices.filter {
            $0.kind == .choose || $0.kind == .later || $0.kind == .rest
        }.map(\.planID))
        let changedDays = Set(plans.filter { changedIDs.contains($0.id) }.map { calendar.startOfDay(for: $0.day) })
            .union(choices.filter { changedIDs.contains($0.planID) && $0.kind != .complete }
                .map { calendar.startOfDay(for: $0.at) })
        let foundations = unambiguous(input.foundations, id: { $0.id }).filter { window.contains($0.day) }
        let foundationGroups = Dictionary(grouping: foundations, by: {
            "\(calendar.startOfDay(for: $0.day).timeIntervalSinceReferenceDate)|\($0.kind.rawValue)"
        })
        let food = unambiguous(input.foodCorrections, id: { $0.id }).filter {
            window.contains($0.at) && !$0.savedDishID.isEmpty && !$0.dishName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let foods = Dictionary(grouping: food, by: \.savedDishID).compactMap { dishID, records -> WeeklyFoodFrequency? in
            guard let latest = records.sorted(by: { $0.at == $1.at ? $0.id < $1.id : $0.at > $1.at }).first else { return nil }
            return WeeklyFoodFrequency(dishID: dishID, name: latest.dishName, count: records.count)
        }.sorted { $0.count == $1.count ? $0.dishID < $1.dishID : $0.count > $1.count }
        return WeeklySummary(
            scope: input.scope, window: window,
            actualSleepMinutes: actual.isEmpty ? nil : actual.reduce(0, +),
            sleepOpportunityMinutes: opportunity.isEmpty ? nil : opportunity.reduce(0, +),
            sleepTrackedDays: actual.count, opportunityTrackedDays: opportunity.count,
            movementMinutes: movement.isEmpty ? nil : movement.reduce(0) { $0 + $1.minutes },
            movementEntries: movement.count,
            healthMovementEntries: movement.filter { $0.source == .health }.count,
            userReportedMovementEntries: movement.filter { $0.source == .userReported }.count,
            sampleMovementEntries: movement.filter { $0.source == .sample }.count,
            plansRecorded: plans.count, plansCompleted: plans.filter(\.completed).count,
            plansChanged: changedIDs.count, changedPlanDays: changedDays.count,
            evidenceChangedPlanIDs: changedIDs.sorted(), alternativesChosen: chosen.count,
            alternativesCompleted: completedAlternativePlans.count,
            foundationsRecorded: foundationGroups.count,
            foundationsDone: foundationGroups.values.filter { $0.contains(where: \.done) }.count,
            foundationsDismissed: foundations.filter(\.dismissed).count,
            foodCorrections: food.count, commonSavedFoods: Array(foods.prefix(3)),
            metrics: WeeklyMetricAggregator.summarize(input.metrics, window: window)
        )
    }

    private static func unambiguous<Value: Equatable>(_ values: [Value], id: (Value) -> String) -> [Value] {
        Dictionary(grouping: values.filter { !id($0).isEmpty }, by: id).values.compactMap { values in
            guard let first = values.first, values.count == 1 || values.allSatisfy({ $0 == first }) else { return nil }
            return first
        }
    }

    private static func sourceAllowed(_ source: WeeklyObservationSource, scope: WeeklyScope) -> Bool {
        scope.isSample ? source != .health : source != .sample
    }

    private static func value(_ observations: [WeeklySleepObservation], select: (WeeklySleepObservation) -> Double?) -> Double? {
        // An explicit correction has precedence. Multiple conflicting values at that level remain unknown.
        for source in [WeeklyObservationSource.userReported, .health, .sample, .localRecord] {
            let values = observations.filter { $0.source == source }.compactMap(select).filter {
                $0.isFinite && (0...1_440).contains($0)
            }
            if !values.isEmpty { return Set(values).count == 1 ? values.first : nil }
        }
        return nil
    }
}
