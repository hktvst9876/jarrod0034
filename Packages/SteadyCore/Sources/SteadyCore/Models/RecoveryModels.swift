import Foundation

public struct RecoveryMetric: Codable, Equatable, Sendable {
    public let current: Double?
    public let baselineMean: Double?
    public let baselineStandardDeviation: Double?
    public let baselineSampleDays: Int

    public init(
        current: Double?,
        baselineMean: Double?,
        baselineStandardDeviation: Double?,
        baselineSampleDays: Int
    ) {
        self.current = current
        self.baselineMean = baselineMean
        self.baselineStandardDeviation = baselineStandardDeviation
        self.baselineSampleDays = max(0, baselineSampleDays)
    }
}

public struct RecoveryInput: Codable, Equatable, Sendable {
    public let daysOfBaseline: Int
    public let sleepLastNightHours: Double?
    public let sleepNeedHours: Double
    public let hrv: RecoveryMetric
    public let restingHeartRate: RecoveryMetric
    public let wristTemperature: RecoveryMetric
    public let respiratoryRate: RecoveryMetric

    public init(
        daysOfBaseline: Int,
        sleepLastNightHours: Double?,
        sleepNeedHours: Double,
        hrv: RecoveryMetric,
        restingHeartRate: RecoveryMetric,
        wristTemperature: RecoveryMetric,
        respiratoryRate: RecoveryMetric
    ) {
        self.daysOfBaseline = max(0, daysOfBaseline)
        self.sleepLastNightHours = sleepLastNightHours
        self.sleepNeedHours = max(0, sleepNeedHours)
        self.hrv = hrv
        self.restingHeartRate = restingHeartRate
        self.wristTemperature = wristTemperature
        self.respiratoryRate = respiratoryRate
    }
}

public enum RecoveryStatus: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case learning
    case recovered
    case normal
    case goEasier
}

public enum RecoveryReasonKind: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case shorterSleep
    case lowerHRV
    case higherRestingHeartRate
    case elevatedTemperatureOrRespiration
}

public struct RecoveryReason: Codable, Equatable, Sendable {
    public let kind: RecoveryReasonKind
    public let message: String

    public init(kind: RecoveryReasonKind, message: String) {
        self.kind = kind
        self.message = message
    }
}

public struct RecoveryContext: Codable, Equatable, Sendable {
    public let status: RecoveryStatus
    public let points: Int?
    public let reasons: [RecoveryReason]
    public let daysOfBaseline: Int
    public let healthNotice: String?

    public init(
        status: RecoveryStatus,
        points: Int?,
        reasons: [RecoveryReason],
        daysOfBaseline: Int,
        healthNotice: String? = nil
    ) {
        self.status = status
        self.points = points.map { max(0, $0) }
        self.reasons = reasons
        self.daysOfBaseline = max(0, daysOfBaseline)
        self.healthNotice = healthNotice
    }

    public static func learning(days: Int) -> RecoveryContext {
        RecoveryContext(
            status: .learning,
            points: nil,
            reasons: [],
            daysOfBaseline: days
        )
    }
}
