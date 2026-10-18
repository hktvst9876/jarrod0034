import Foundation
import SteadyCore

struct SampleHealthProvider: HealthDataProviding {
    let now: Date

    func accessState() async -> HealthAccessState { .requestCompleted }
    func requestReadAccess() async throws -> HealthAccessState { .requestCompleted }

    func sleepSamples(in interval: DateInterval) async throws -> [SleepSample] {
        let calendar = SteadyCalendar.singapore()
        let today = calendar.startOfDay(for: now)
        var samples: [SleepSample] = []

        for offset in 0..<30 where offset != 9 {
            guard let wakeDay = calendar.date(byAdding: .day, value: -offset, to: today),
                  let wake = calendar.date(bySettingHour: 7 + (offset % 3 == 0 ? 1 : 0), minute: 25, second: 0, of: wakeDay),
                  let start = calendar.date(byAdding: .minute, value: -(420 + (offset % 4) * 20), to: wake) else {
                continue
            }
            let sample = SleepSample(
                id: stableID(for: offset),
                start: start,
                end: wake,
                stage: .unspecified,
                sourceID: "steady.sample"
            )
            if sample.end > interval.start && sample.start < interval.end {
                samples.append(sample)
            }
        }
        return samples
    }

    func activityContext(on day: Date, calendar: Calendar) async throws -> ActivityContext {
        ActivityContext(
            stepsToday: 4_860,
            exerciseMinutesToday: 18,
            daysSinceExercise: 1,
            lastWorkoutEnd: calendar.date(byAdding: .day, value: -1, to: day)
        )
    }

    func safetyFlags(on day: Date, calendar: Calendar) async throws -> [SafetyFlag] { [] }

    func workoutIntervals(in range: DateRange) async throws -> [DateRange] {
        let calendar = SteadyCalendar.singapore()
        guard let start = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: range.start),
              let end = calendar.date(byAdding: .minute, value: 20, to: start),
              end > range.start, start < range.end else { return [] }
        return [DateRange(start: start, end: end)]
    }

    func recoveryInput(
        on day: Date,
        sleepLastNightHours: Double?,
        sleepNeedHours: Double,
        calendar: Calendar
    ) async throws -> RecoveryInput {
        RecoveryInput(
            daysOfBaseline: 21,
            sleepLastNightHours: sleepLastNightHours,
            sleepNeedHours: sleepNeedHours,
            hrv: RecoveryMetric(current: 48, baselineMean: 51, baselineStandardDeviation: 7, baselineSampleDays: 21),
            restingHeartRate: RecoveryMetric(current: 62, baselineMean: 60, baselineStandardDeviation: 4, baselineSampleDays: 21),
            wristTemperature: RecoveryMetric(current: 0.08, baselineMean: 0, baselineStandardDeviation: 0.18, baselineSampleDays: 21),
            respiratoryRate: RecoveryMetric(current: 15.2, baselineMean: 15, baselineStandardDeviation: 0.8, baselineSampleDays: 21)
        )
    }

    private func stableID(for offset: Int) -> UUID {
        let suffix = String(format: "%012d", offset + 1)
        return UUID(uuidString: "00000000-0000-0000-0000-\(suffix)") ?? UUID()
    }
}
