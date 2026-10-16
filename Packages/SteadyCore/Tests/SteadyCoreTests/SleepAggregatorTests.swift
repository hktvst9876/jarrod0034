import Foundation
import Testing
@testable import SteadyCore

@Suite("Sleep aggregation")
struct SleepAggregatorTests {
    @Test("Overlapping sources count time once across midnight")
    func mergesOverlappingSources() throws {
        let samples = [
            sample(start: testDate(2026, 10, 15, 22), end: testDate(2026, 10, 16, 6), source: "watch"),
            sample(start: testDate(2026, 10, 15, 23), end: testDate(2026, 10, 16, 7), source: "phone")
        ]

        let night = try #require(
            SleepAggregator.night(for: testDate(), samples: samples, calendar: testCalendar)
        )
        #expect(night.asleepMinutes == 9 * 60)
        #expect(night.sleepStart == testDate(2026, 10, 15, 22))
        #expect(night.wakeTime == testDate(2026, 10, 16, 7))
        #expect(night.sourceCount == 2)
    }

    @Test("Daytime nap is excluded from the night")
    func excludesNap() throws {
        let samples = [
            sample(start: testDate(2026, 10, 15, 23), end: testDate(2026, 10, 16, 7)),
            sample(start: testDate(2026, 10, 16, 13), end: testDate(2026, 10, 16, 14))
        ]

        let night = try #require(SleepAggregator.night(for: testDate(), samples: samples))
        #expect(night.asleepMinutes == 8 * 60)
        #expect(night.wakeTime == testDate(2026, 10, 16, 7))
    }

    @Test("Awake and in-bed samples do not inflate asleep time")
    func separatesStages() throws {
        let samples = [
            sample(start: testDate(2026, 10, 15, 22, 30), end: testDate(2026, 10, 16, 7, 30), stage: .inBed),
            sample(start: testDate(2026, 10, 15, 23), end: testDate(2026, 10, 16, 3), stage: .core),
            sample(start: testDate(2026, 10, 16, 3), end: testDate(2026, 10, 16, 3, 30), stage: .awake),
            sample(start: testDate(2026, 10, 16, 3, 30), end: testDate(2026, 10, 16, 7), stage: .rem)
        ]

        let night = try #require(SleepAggregator.night(for: testDate(), samples: samples))
        #expect(night.asleepMinutes == 7 * 60 + 30)
        #expect(night.inBedMinutes == 9 * 60)
    }

    @Test("Invalid and out-of-window samples are ignored")
    func ignoresInvalidSamples() {
        let samples = [
            sample(start: testDate(2026, 10, 15, 17), end: testDate(2026, 10, 15, 17, 30)),
            sample(start: testDate(2026, 10, 16, 8), end: testDate(2026, 10, 16, 7))
        ]
        #expect(SleepAggregator.night(for: testDate(), samples: samples) == nil)
    }

    @Test("Multi-night aggregation leaves missing nights absent")
    func missingNightsAreAbsent() {
        let samples = [
            sample(start: testDate(2026, 10, 14, 23), end: testDate(2026, 10, 15, 7)),
            sample(start: testDate(2026, 10, 15, 23), end: testDate(2026, 10, 16, 7))
        ]
        let nights = SleepAggregator.nights(endingOn: testDate(), count: 7, samples: samples)
        #expect(nights.count == 2)
        #expect(nights.map(\.wakeDay) == [testDate(2026, 10, 15), testDate(2026, 10, 16)])
    }
}

private extension SleepAggregatorTests {
    func sample(
        start: Date,
        end: Date,
        stage: SleepStage = .unspecified,
        source: String = "watch"
    ) -> SleepSample {
        SleepSample(id: UUID(), start: start, end: end, stage: stage, sourceID: source)
    }
}
