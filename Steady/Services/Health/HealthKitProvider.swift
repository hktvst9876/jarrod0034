@preconcurrency import HealthKit
import Foundation
import SteadyCore

actor HealthKitProvider: HealthDataProviding {
    let store: HKHealthStore
    private var requestWasCompleted = false

    init(store: HKHealthStore = HKHealthStore()) {
        self.store = store
    }

    func accessState() -> HealthAccessState {
        guard HKHealthStore.isHealthDataAvailable() else { return .notAvailable }
        return requestWasCompleted ? .requestCompleted : .notRequested
    }

    func requestReadAccess() async throws -> HealthAccessState {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthDataError.unavailable
        }
        try await store.requestAuthorization(toShare: [], read: try readTypes())
        requestWasCompleted = true
        return .requestCompleted
    }

    func sleepSamples(in interval: DateInterval) async throws -> [SleepSample] {
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else {
            throw HealthDataError.typeUnavailable("sleep")
        }
        let samples = try await categorySamples(type: type, start: interval.start, end: interval.end)
        return samples.map {
            SleepSample(
                id: $0.uuid,
                start: $0.startDate,
                end: $0.endDate,
                stage: sleepStage(for: $0.value),
                sourceID: $0.sourceRevision.source.bundleIdentifier
            )
        }
    }

    func activityContext(on day: Date, calendar: Calendar) async throws -> ActivityContext {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? day
        let steps = try await cumulativeValue(.stepCount, unit: .count(), start: start, end: end)
        let exercise = try await cumulativeValue(.appleExerciseTime, unit: .minute(), start: start, end: end)
        let latestWorkout = try await latestWorkout(endingAt: end, calendar: calendar)
        let daysSinceExercise = latestWorkout.map {
            max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: $0), to: start).day ?? 0)
        }
        return ActivityContext(
            stepsToday: steps.map { Int($0.rounded()) },
            exerciseMinutesToday: exercise.map { Int($0.rounded()) },
            daysSinceExercise: daysSinceExercise,
            lastWorkoutEnd: latestWorkout
        )
    }

    func recoveryInput(
        on day: Date,
        sleepLastNightHours: Double?,
        sleepNeedHours: Double,
        calendar: Calendar
    ) async throws -> RecoveryInput {
        async let hrvResult = recoveryMetric(
            identifier: .heartRateVariabilitySDNN,
            unit: .secondUnit(with: .milli), day: day, calendar: calendar
        )
        async let heartResult = recoveryMetric(
            identifier: .restingHeartRate,
            unit: .count().unitDivided(by: .minute()), day: day, calendar: calendar
        )
        async let temperatureResult = recoveryMetric(
            identifier: .appleSleepingWristTemperature,
            unit: .degreeCelsius(), day: day, calendar: calendar
        )
        async let respirationResult = recoveryMetric(
            identifier: .respiratoryRate,
            unit: .count().unitDivided(by: .minute()), day: day, calendar: calendar
        )
        let (hrv, heart, temperature, respiration) = try await (
            hrvResult, heartResult, temperatureResult, respirationResult
        )
        let availableDays = [hrv.days, heart.days, temperature.days, respiration.days].filter { $0 > 0 }
        return RecoveryInput(
            daysOfBaseline: availableDays.min() ?? 0,
            sleepLastNightHours: sleepLastNightHours,
            sleepNeedHours: sleepNeedHours,
            hrv: hrv.metric,
            restingHeartRate: heart.metric,
            wristTemperature: temperature.metric,
            respiratoryRate: respiration.metric
        )
    }

    func safetyFlags(on day: Date, calendar: Calendar) async throws -> [SafetyFlag] {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? day
        let identifiers: [(HKCategoryTypeIdentifier, String)] = [
            (.highHeartRateEvent, "high heart rate alert"),
            (.lowHeartRateEvent, "low heart rate alert"),
            (.irregularHeartRhythmEvent, "irregular rhythm alert")
        ]
        var flags: [SafetyFlag] = []
        for (identifier, label) in identifiers {
            guard let type = HKObjectType.categoryType(forIdentifier: identifier) else { continue }
            let samples = try await categorySamples(type: type, start: start, end: end)
            flags.append(contentsOf: samples.map { .healthAlert(kind: label, at: $0.endDate) })
        }
        return flags
    }

    private func readTypes() throws -> Set<HKObjectType> {
        let quantities: [HKQuantityTypeIdentifier] = [
            .stepCount, .appleExerciseTime, .restingHeartRate,
            .heartRateVariabilitySDNN, .respiratoryRate, .appleSleepingWristTemperature
        ]
        let categories: [HKCategoryTypeIdentifier] = [
            .sleepAnalysis, .highHeartRateEvent, .lowHeartRateEvent, .irregularHeartRhythmEvent
        ]
        var types = Set<HKObjectType>([HKObjectType.workoutType()])
        quantities.compactMap { HKObjectType.quantityType(forIdentifier: $0) }.forEach { types.insert($0) }
        categories.compactMap { HKObjectType.categoryType(forIdentifier: $0) }.forEach { types.insert($0) }
        guard types.contains(where: { $0.identifier == HKCategoryTypeIdentifier.sleepAnalysis.rawValue }) else {
            throw HealthDataError.typeUnavailable("sleep")
        }
        return types
    }

    private func sleepStage(for value: Int) -> SleepStage {
        switch value {
        case HKCategoryValueSleepAnalysis.asleepCore.rawValue: .core
        case HKCategoryValueSleepAnalysis.asleepDeep.rawValue: .deep
        case HKCategoryValueSleepAnalysis.asleepREM.rawValue: .rem
        case HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue: .unspecified
        case HKCategoryValueSleepAnalysis.inBed.rawValue: .inBed
        case HKCategoryValueSleepAnalysis.awake.rawValue: .awake
        default: .other
        }
    }
}

