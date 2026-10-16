@preconcurrency import HealthKit
import Foundation
import SteadyCore

extension HealthKitProvider {
    func categorySamples(type: HKCategoryType, start: Date, end: Date) async throws -> [HKCategorySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKCategorySample] ?? [])
                }
            }
            store.execute(query)
        }
    }

    func cumulativeValue(
        _ identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        start: Date,
        end: Date
    ) async throws -> Double? {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum
            ) { _, result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: result?.sumQuantity()?.doubleValue(for: unit))
                }
            }
            store.execute(query)
        }
    }

    func latestWorkout(endingAt end: Date, calendar: Calendar) async throws -> Date? {
        guard let start = calendar.date(byAdding: .day, value: -30, to: end) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(), predicate: predicate, limit: 1,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples?.first?.endDate)
                }
            }
            store.execute(query)
        }
    }

    func recoveryMetric(
        identifier: HKQuantityTypeIdentifier,
        unit: HKUnit,
        day: Date,
        calendar: Calendar
    ) async throws -> (metric: RecoveryMetric, days: Int) {
        guard let type = HKObjectType.quantityType(forIdentifier: identifier) else {
            return (emptyRecoveryMetric(), 0)
        }
        let dayStart = calendar.startOfDay(for: day)
        let currentStart = calendar.date(byAdding: .hour, value: -12, to: dayStart) ?? dayStart
        let currentEnd = calendar.date(byAdding: .hour, value: 12, to: dayStart) ?? day
        let baselineStart = calendar.date(byAdding: .day, value: -28, to: currentStart) ?? currentStart
        let currentSamples = try await quantitySamples(type: type, start: currentStart, end: currentEnd)
        let baselineSamples = try await quantitySamples(type: type, start: baselineStart, end: currentStart)
        let current = average(currentSamples.map { $0.quantity.doubleValue(for: unit) })
        let dailyValues = Dictionary(grouping: baselineSamples) {
            calendar.startOfDay(for: $0.endDate)
        }.values.compactMap { samples in
            average(samples.map { $0.quantity.doubleValue(for: unit) })
        }
        let dayCount = dailyValues.count
        let baselineMean = dayCount >= 7 ? average(dailyValues) : nil
        let deviation = baselineMean.map { mean in
            sqrt(dailyValues.map { pow($0 - mean, 2) }.reduce(0, +) / Double(dayCount))
        }
        return (
            RecoveryMetric(
                current: current, baselineMean: baselineMean,
                baselineStandardDeviation: deviation, baselineSampleDays: dayCount
            ),
            dayCount
        )
    }

    func quantitySamples(type: HKQuantityType, start: Date, end: Date) async throws -> [HKQuantitySample] {
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)]
            ) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
                }
            }
            store.execute(query)
        }
    }

    private func average(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }

    private func emptyRecoveryMetric() -> RecoveryMetric {
        RecoveryMetric(
            current: nil, baselineMean: nil, baselineStandardDeviation: nil, baselineSampleDays: 0
        )
    }
}

