@preconcurrency import HealthKit
import Foundation
import SteadyCore

extension HealthKitProvider {
    func workoutIntervals(in range: DateRange) async throws -> [DateRange] {
        let predicate = HKQuery.predicateForSamples(withStart: range.start, end: range.end, options: [])
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKObjectType.workoutType(), predicate: predicate,
                limit: HKObjectQueryNoLimit, sortDescriptors: nil
            ) { _, samples, error in
                if let error { continuation.resume(throwing: error) }
                else {
                    let ranges = (samples ?? []).map { DateRange(start: $0.startDate, end: $0.endDate) }
                    continuation.resume(returning: ranges)
                }
            }
            store.execute(query)
        }
    }
}
