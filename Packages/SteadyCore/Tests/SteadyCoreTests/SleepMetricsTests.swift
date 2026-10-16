import Foundation
import Testing
@testable import SteadyCore

@Suite("Sleep metrics")
struct SleepMetricsTests {
    @Test("Shortfall sums deficits without offsetting them with long nights")
    func shortfallDoesNotNetSurplus() {
        let nights = [night(day: 14, asleepMinutes: 6 * 60), night(day: 15, asleepMinutes: 9 * 60)]
        let result = SleepMetrics.shortfall(
            endingOn: testDate(),
            over: nights,
            sleepNeedMinutes: 8 * 60
        )

        #expect(result.totalMinutes == 2 * 60)
        #expect(result.nightsTracked == 2)
        #expect(result.windowDays == 7)
    }

    @Test("Missing and future nights do not become zero-hour nights")
    func excludesMissingAndFutureNights() {
        let nights = [
            night(day: 15, asleepMinutes: 7 * 60),
            night(day: 17, asleepMinutes: 1)
        ]
        let result = SleepMetrics.shortfall(
            endingOn: testDate(),
            over: nights,
            sleepNeedMinutes: 8 * 60
        )

        #expect(result.totalMinutes == 60)
        #expect(result.nightsTracked == 1)
    }

    @Test("Old nights outside the seven-day window are excluded")
    func excludesOldNights() {
        let result = SleepMetrics.shortfall(
            endingOn: testDate(),
            over: [night(day: 8, asleepMinutes: 1), night(day: 16, asleepMinutes: 8 * 60)],
            sleepNeedMinutes: 8 * 60
        )
        #expect(result.totalMinutes == 0)
        #expect(result.nightsTracked == 1)
    }

    @Test("Wake consistency handles times around midnight")
    func circularWakeTimes() throws {
        let nights = [
            night(day: 15, asleepMinutes: 8 * 60, wakeHour: 23, wakeMinute: 50),
            night(day: 16, asleepMinutes: 8 * 60, wakeHour: 0, wakeMinute: 10)
        ]
        let result = try #require(
            SleepMetrics.wakeConsistency(endingOn: testDate(), over: nights)
        )
        #expect(result.meanAbsoluteDeviationMinutes == 10)
        #expect(result.label == .steady)
    }

    @Test("Wake consistency uses the documented thresholds")
    func consistencyThresholds() throws {
        let somewhat = try #require(
            SleepMetrics.wakeConsistency(
                endingOn: testDate(),
                over: [
                    night(day: 15, asleepMinutes: 480, wakeHour: 7),
                    night(day: 16, asleepMinutes: 480, wakeHour: 9)
                ]
            )
        )
        let irregular = try #require(
            SleepMetrics.wakeConsistency(
                endingOn: testDate(),
                over: [
                    night(day: 15, asleepMinutes: 480, wakeHour: 7),
                    night(day: 16, asleepMinutes: 480, wakeHour: 10)
                ]
            )
        )
        #expect(somewhat.label == .aBitIrregular)
        #expect(irregular.label == .irregular)
    }

    @Test("One wake time is not enough for a consistency claim")
    func insufficientConsistencyData() {
        let result = SleepMetrics.wakeConsistency(
            endingOn: testDate(),
            over: [night(day: 16, asleepMinutes: 480)]
        )
        #expect(result == nil)
    }
}

private extension SleepMetricsTests {
    func night(
        day: Int,
        asleepMinutes: Int,
        wakeHour: Int = 7,
        wakeMinute: Int = 0
    ) -> SleepNight {
        SleepNight(
            wakeDay: testDate(2026, 10, day),
            sleepStart: testDate(2026, 10, day - 1, 23),
            wakeTime: testDate(2026, 10, day, wakeHour, wakeMinute),
            asleepMinutes: asleepMinutes,
            sourceCount: 1
        )
    }
}
