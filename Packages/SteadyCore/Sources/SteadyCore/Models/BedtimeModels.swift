import Foundation

public struct BedtimePlanInput: Codable, Equatable, Sendable {
    public let tomorrow: Date
    public let usualWakeTime: TimeOfDay
    public let commitments: [CalendarCommitment]
    public let travelMinutes: Int
    public let morningRoutineMinutes: Int
    public let sleepNeedMinutes: Int
    public let sleepLatencyMinutes: Int
    public let windDownMinutes: Int
    public let caffeineCutoffMinutes: Int

    public init(
        tomorrow: Date,
        usualWakeTime: TimeOfDay,
        commitments: [CalendarCommitment],
        travelMinutes: Int,
        morningRoutineMinutes: Int,
        sleepNeedMinutes: Int,
        sleepLatencyMinutes: Int = 15,
        windDownMinutes: Int = 45,
        caffeineCutoffMinutes: Int = 8 * 60
    ) {
        self.tomorrow = tomorrow
        self.usualWakeTime = usualWakeTime
        self.commitments = commitments
        self.travelMinutes = max(0, travelMinutes)
        self.morningRoutineMinutes = max(0, morningRoutineMinutes)
        self.sleepNeedMinutes = max(0, sleepNeedMinutes)
        self.sleepLatencyMinutes = max(0, sleepLatencyMinutes)
        self.windDownMinutes = max(0, windDownMinutes)
        self.caffeineCutoffMinutes = max(0, caffeineCutoffMinutes)
    }
}

public struct BedtimePlan: Codable, Equatable, Sendable {
    public let wakeTime: Date
    public let unclampedWakeTime: Date
    public let bedtime: Date
    public let bedtimeWindowStart: Date
    public let bedtimeWindowEnd: Date
    public let windDownTime: Date
    public let caffeineCutoffTime: Date
    public let firstCommitment: Date?
    public let isWakeTimeClamped: Bool
    public let needsEarlyWakeHeadsUp: Bool
    public let explanation: String

    public init(
        wakeTime: Date,
        unclampedWakeTime: Date,
        bedtime: Date,
        bedtimeWindowStart: Date,
        bedtimeWindowEnd: Date,
        windDownTime: Date,
        caffeineCutoffTime: Date,
        firstCommitment: Date?,
        isWakeTimeClamped: Bool,
        needsEarlyWakeHeadsUp: Bool,
        explanation: String
    ) {
        self.wakeTime = wakeTime
        self.unclampedWakeTime = unclampedWakeTime
        self.bedtime = bedtime
        self.bedtimeWindowStart = bedtimeWindowStart
        self.bedtimeWindowEnd = bedtimeWindowEnd
        self.windDownTime = windDownTime
        self.caffeineCutoffTime = caffeineCutoffTime
        self.firstCommitment = firstCommitment
        self.isWakeTimeClamped = isWakeTimeClamped
        self.needsEarlyWakeHeadsUp = needsEarlyWakeHeadsUp
        self.explanation = explanation
    }
}
