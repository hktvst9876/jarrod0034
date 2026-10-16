import Foundation
import SteadyCore

enum HealthAccessState: Sendable, Equatable {
    case notAvailable
    case notRequested
    case requestCompleted
}

protocol HealthDataProviding: Sendable {
    func accessState() async -> HealthAccessState
    func requestReadAccess() async throws -> HealthAccessState
    func sleepSamples(in interval: DateInterval) async throws -> [SleepSample]
    func activityContext(on day: Date, calendar: Calendar) async throws -> ActivityContext
    func safetyFlags(on day: Date, calendar: Calendar) async throws -> [SafetyFlag]
    func recoveryInput(
        on day: Date,
        sleepLastNightHours: Double?,
        sleepNeedHours: Double,
        calendar: Calendar
    ) async throws -> RecoveryInput
}

enum HealthDataError: LocalizedError {
    case unavailable
    case typeUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "Apple Health is not available on this device."
        case .typeUnavailable(let name):
            "The Health data type \(name) is not available on this device."
        }
    }
}

