import Foundation
import Testing
@testable import SteadyCore

@Suite("Recovery context")
struct RecoveryEvaluatorTests {
    @Test("Fewer than seven baseline days stays in learning")
    func learnsBaseline() {
        let result = RecoveryEvaluator.evaluate(input(days: 6, sleep: 5))
        #expect(result.status == .learning)
        #expect(result.points == nil)
    }

    @Test("No current signals never becomes recovered")
    func missingSignalsAreNeutral() {
        let result = RecoveryEvaluator.evaluate(input(days: 30, sleep: nil))
        #expect(result.status == .learning)
        #expect(result.points == nil)
        #expect(result.reasons.isEmpty)
    }

    @Test("Zero points is recovered but never intensifies a plan")
    func zeroPoints() {
        let result = RecoveryEvaluator.evaluate(input(days: 30, sleep: 8))
        #expect(result.status == .recovered)
        #expect(result.points == 0)
    }

    @Test("One signal is normal and two signals mean go easier")
    func pointThresholds() {
        let one = RecoveryEvaluator.evaluate(input(days: 30, sleep: 6.5))
        let two = RecoveryEvaluator.evaluate(
            input(days: 30, sleep: 6.5, restingHeartRate: testMetric(current: 66, mean: 60, days: 30))
        )
        #expect(one.status == .normal)
        #expect(one.points == 1)
        #expect(two.status == .goEasier)
        #expect(two.points == 2)
    }

    @Test("Temperature and respiration together contribute only one point")
    func combinedBodySignal() {
        let result = RecoveryEvaluator.evaluate(
            input(
                days: 30,
                sleep: 8,
                temperature: testMetric(current: 36.7, mean: 36.0, days: 30),
                respiratoryRate: testMetric(current: 18.5, mean: 16, days: 30)
            )
        )
        #expect(result.points == 1)
        #expect(result.reasons.count == 1)
        #expect(result.healthNotice?.contains("medical advice") == true)
        #expect(result.healthNotice?.contains("fighting") == false)
    }

    @Test("A metric with too little baseline coverage is skipped")
    func metricCoverageGuard() {
        let result = RecoveryEvaluator.evaluate(
            input(
                days: 30,
                sleep: 8,
                restingHeartRate: testMetric(current: 90, mean: 60, days: 6)
            )
        )
        #expect(result.status == .recovered)
        #expect(result.points == 0)
    }
}

private extension RecoveryEvaluatorTests {
    func input(
        days: Int,
        sleep: Double?,
        hrv: RecoveryMetric = testMetric(),
        restingHeartRate: RecoveryMetric = testMetric(),
        temperature: RecoveryMetric = testMetric(),
        respiratoryRate: RecoveryMetric = testMetric()
    ) -> RecoveryInput {
        RecoveryInput(
            daysOfBaseline: days,
            sleepLastNightHours: sleep,
            sleepNeedHours: 8,
            hrv: hrv,
            restingHeartRate: restingHeartRate,
            wristTemperature: temperature,
            respiratoryRate: respiratoryRate
        )
    }
}
