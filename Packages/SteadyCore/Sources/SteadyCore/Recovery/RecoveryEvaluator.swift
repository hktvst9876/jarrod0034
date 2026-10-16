import Foundation

public enum RecoveryEvaluator {
    public static let minimumBaselineDays = 7

    public static func evaluate(_ input: RecoveryInput) -> RecoveryContext {
        guard input.daysOfBaseline >= minimumBaselineDays else {
            return .learning(days: input.daysOfBaseline)
        }

        guard hasAnyUsableSignal(input) else {
            return .learning(days: input.daysOfBaseline)
        }

        var points = 0
        var reasons: [RecoveryReason] = []

        if let sleep = input.sleepLastNightHours,
           sleep < input.sleepNeedHours - 1 {
            points += 1
            reasons.append(
                RecoveryReason(
                    kind: .shorterSleep,
                    message: "You slept less than your usual need."
                )
            )
        }

        if isLowHRV(input.hrv) {
            points += 1
            reasons.append(
                RecoveryReason(
                    kind: .lowerHRV,
                    message: "Your overnight heart-rate variability is below your usual range."
                )
            )
        }

        if isHighRestingHeartRate(input.restingHeartRate) {
            points += 1
            reasons.append(
                RecoveryReason(
                    kind: .higherRestingHeartRate,
                    message: "Your resting heart rate is above your usual range."
                )
            )
        }

        let temperatureOrRespirationIsElevated = isHighTemperature(input.wristTemperature)
            || isHighRespiratoryRate(input.respiratoryRate)
        if temperatureOrRespirationIsElevated {
            points += 1
            reasons.append(
                RecoveryReason(
                    kind: .elevatedTemperatureOrRespiration,
                    message: "A temperature or breathing reading is above your usual range."
                )
            )
        }

        let status: RecoveryStatus
        switch points {
        case 0:
            status = .recovered
        case 1:
            status = .normal
        default:
            status = .goEasier
        }

        let notice = temperatureOrRespirationIsElevated
            ? "Take it easy, and seek medical advice if you feel unwell."
            : nil

        return RecoveryContext(
            status: status,
            points: points,
            reasons: reasons,
            daysOfBaseline: input.daysOfBaseline,
            healthNotice: notice
        )
    }
}

private extension RecoveryEvaluator {
    static func hasAnyUsableSignal(_ input: RecoveryInput) -> Bool {
        input.sleepLastNightHours != nil
            || hasCompleteBaseline(input.hrv, requiresStandardDeviation: true)
            || hasCompleteBaseline(input.restingHeartRate, requiresStandardDeviation: false)
            || hasCompleteBaseline(input.wristTemperature, requiresStandardDeviation: false)
            || hasCompleteBaseline(input.respiratoryRate, requiresStandardDeviation: false)
    }

    static func hasCompleteBaseline(
        _ metric: RecoveryMetric,
        requiresStandardDeviation: Bool
    ) -> Bool {
        guard hasUsableBaseline(metric),
              metric.current != nil,
              metric.baselineMean != nil else {
            return false
        }
        return !requiresStandardDeviation || metric.baselineStandardDeviation != nil
    }

    static func hasUsableBaseline(_ metric: RecoveryMetric) -> Bool {
        metric.baselineSampleDays >= minimumBaselineDays
    }

    static func isLowHRV(_ metric: RecoveryMetric) -> Bool {
        guard hasUsableBaseline(metric),
              let current = metric.current,
              let mean = metric.baselineMean,
              let standardDeviation = metric.baselineStandardDeviation,
              standardDeviation >= 0 else {
            return false
        }
        return current < mean - standardDeviation
    }

    static func isHighRestingHeartRate(_ metric: RecoveryMetric) -> Bool {
        guard hasUsableBaseline(metric),
              let current = metric.current,
              let mean = metric.baselineMean else {
            return false
        }
        return current > mean + 5
    }

    static func isHighTemperature(_ metric: RecoveryMetric) -> Bool {
        guard hasUsableBaseline(metric),
              let current = metric.current,
              let mean = metric.baselineMean else {
            return false
        }
        return current > mean + 0.5
    }

    static func isHighRespiratoryRate(_ metric: RecoveryMetric) -> Bool {
        guard hasUsableBaseline(metric),
              let current = metric.current,
              let mean = metric.baselineMean else {
            return false
        }
        return current > mean + 2
    }
}
