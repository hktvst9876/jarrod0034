import Foundation

public enum SleepStage: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case core
    case deep
    case rem
    case unspecified
    case inBed
    case awake
    case other

    public var countsAsSleep: Bool {
        switch self {
        case .core, .deep, .rem, .unspecified:
            true
        case .inBed, .awake, .other:
            false
        }
    }
}

public struct SleepSample: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let start: Date
    public let end: Date
    public let stage: SleepStage
    public let sourceID: String

    public init(
        id: UUID,
        start: Date,
        end: Date,
        stage: SleepStage,
        sourceID: String
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.stage = stage
        self.sourceID = sourceID
    }
}

public struct SleepNight: Codable, Equatable, Sendable {
    public let wakeDay: Date
    public let sleepStart: Date
    public let wakeTime: Date
    public let asleepMinutes: Int
    public let inBedMinutes: Int?
    public let sourceCount: Int

    public init(
        wakeDay: Date,
        sleepStart: Date,
        wakeTime: Date,
        asleepMinutes: Int,
        inBedMinutes: Int? = nil,
        sourceCount: Int
    ) {
        self.wakeDay = wakeDay
        self.sleepStart = sleepStart
        self.wakeTime = wakeTime
        self.asleepMinutes = max(0, asleepMinutes)
        self.inBedMinutes = inBedMinutes.map { max(0, $0) }
        self.sourceCount = max(0, sourceCount)
    }
}

public enum SleepLabel: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case shorter
    case usual
    case longer
    case unknown
}

public struct SleepShortfall: Codable, Equatable, Sendable {
    public let totalMinutes: Int
    public let nightsTracked: Int
    public let windowDays: Int

    public init(totalMinutes: Int, nightsTracked: Int, windowDays: Int) {
        self.totalMinutes = max(0, totalMinutes)
        self.nightsTracked = max(0, nightsTracked)
        self.windowDays = max(0, windowDays)
    }

    public var totalHours: Double {
        Double(totalMinutes) / 60
    }
}

public enum WakeConsistencyLabel: String, Codable, CaseIterable, Equatable, Hashable, Sendable {
    case steady
    case aBitIrregular
    case irregular
}

public struct WakeConsistencySummary: Codable, Equatable, Sendable {
    public let meanAbsoluteDeviationMinutes: Double
    public let label: WakeConsistencyLabel
    public let nightsTracked: Int

    public init(
        meanAbsoluteDeviationMinutes: Double,
        label: WakeConsistencyLabel,
        nightsTracked: Int
    ) {
        self.meanAbsoluteDeviationMinutes = max(0, meanAbsoluteDeviationMinutes)
        self.label = label
        self.nightsTracked = max(0, nightsTracked)
    }
}

public struct SleepContext: Codable, Equatable, Sendable {
    public let lastNight: SleepNight?
    public let coarseLabel: SleepLabel
    public let shortfall7dMinutes: Int?
    public let nightsTracked: Int
    public let wakeConsistency: WakeConsistencySummary?
    public let bedtimePlan: BedtimePlan?

    public init(
        lastNight: SleepNight?,
        coarseLabel: SleepLabel,
        shortfall7dMinutes: Int?,
        nightsTracked: Int,
        wakeConsistency: WakeConsistencySummary?,
        bedtimePlan: BedtimePlan?
    ) {
        self.lastNight = lastNight
        self.coarseLabel = coarseLabel
        self.shortfall7dMinutes = shortfall7dMinutes.map { max(0, $0) }
        self.nightsTracked = max(0, nightsTracked)
        self.wakeConsistency = wakeConsistency
        self.bedtimePlan = bedtimePlan
    }

    public static let missing = SleepContext(
        lastNight: nil,
        coarseLabel: .unknown,
        shortfall7dMinutes: nil,
        nightsTracked: 0,
        wakeConsistency: nil,
        bedtimePlan: nil
    )
}
