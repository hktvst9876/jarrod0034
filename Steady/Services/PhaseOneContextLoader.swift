import Foundation
import SteadyCore

struct PhaseOneContextSnapshot: Sendable {
    let sleep: SleepContext
    let activity: ActivityContext
    let recovery: RecoveryContext
    let availability: Availability
    let safetyFlags: [SafetyFlag]
    let dataGaps: Set<DataGap>
}

struct PhaseOneContextLoader: Sendable {
    let health: any HealthDataProviding
    let calendarProvider: any CalendarProviding
    let calendar: Calendar

    func load(
        at now: Date,
        profile: Profile,
        ignoreLastNightSleep: Bool = false,
        manualFreeMinutes: Int? = nil
    ) async -> PhaseOneContextSnapshot {
        let sleepResult = await loadSleep(at: now, needMinutes: profile.sleep.sleepNeedMinutes)
        let visibleSleep = ignoreLastNightSleep
            ? sleepWithoutLastNight(sleepResult.context)
            : sleepResult.context

        let bedtimePlan = await loadBedtimePlan(at: now, preferences: profile.sleep)
        async let activityValue = optionalActivity(at: now)
        async let safetyValue = optionalSafetyFlags(at: now)
        async let availabilityValue = loadAvailability(
            at: now,
            sleepPreferences: profile.sleep,
            bedtimePlan: bedtimePlan,
            preferredPeriod: profile.movement.preferredWorkoutTime,
            manualFreeMinutes: manualFreeMinutes
        )

        let activity = await activityValue
        let safetyFlags = await safetyValue
        let availability = await availabilityValue
        let sleep = SleepContext(
            lastNight: visibleSleep.lastNight,
            coarseLabel: visibleSleep.coarseLabel,
            shortfall7dMinutes: visibleSleep.shortfall7dMinutes,
            nightsTracked: visibleSleep.nightsTracked,
            wakeConsistency: visibleSleep.wakeConsistency,
            bedtimePlan: bedtimePlan
        )

        let recovery = await loadRecovery(
            at: now,
            lastNightHours: sleep.lastNight.map { Double($0.asleepMinutes) / 60 },
            sleepNeedHours: Double(profile.sleep.sleepNeedMinutes) / 60
        )
        var gaps = sleepResult.gaps
        if ignoreLastNightSleep { gaps.insert(.sleep) }
        if activity == .missing { gaps.insert(.activity) }
        if recovery.status == .learning { gaps.insert(.recovery) }
        if availability.source == .unknown { gaps.insert(.calendar) }

        return PhaseOneContextSnapshot(
            sleep: sleep,
            activity: activity,
            recovery: recovery,
            availability: availability,
            safetyFlags: safetyFlags,
            dataGaps: gaps
        )
    }

    private func loadSleep(at now: Date, needMinutes: Int) async -> (context: SleepContext, gaps: Set<DataGap>) {
        guard let queryStart = calendar.date(byAdding: .day, value: -8, to: now),
              let queryEnd = calendar.date(byAdding: .hour, value: 18, to: calendar.startOfDay(for: now)) else {
            return (.missing, [.sleep])
        }
        do {
            let queriedSamples = try await health.sleepSamples(in: DateInterval(start: queryStart, end: queryEnd))
            let samples = queriedSamples.filter { $0.end <= now }
            let nights = SleepAggregator.nights(endingOn: now, count: 7, samples: samples, calendar: calendar)
            let lastNight = SleepAggregator.night(for: now, samples: samples, calendar: calendar)
            let shortfall = SleepMetrics.shortfall(
                endingOn: now,
                over: nights,
                sleepNeedMinutes: needMinutes,
                calendar: calendar
            )
            let consistency = SleepMetrics.wakeConsistency(
                endingOn: now,
                over: nights,
                calendar: calendar
            )
            let context = SleepContext(
                lastNight: lastNight,
                coarseLabel: SleepMetrics.coarseLabel(
                    asleepMinutes: lastNight?.asleepMinutes,
                    sleepNeedMinutes: needMinutes
                ),
                shortfall7dMinutes: shortfall.nightsTracked > 0 ? shortfall.totalMinutes : nil,
                nightsTracked: shortfall.nightsTracked,
                wakeConsistency: consistency,
                bedtimePlan: nil
            )
            return (context, lastNight == nil ? [.sleep] : [])
        } catch {
            return (.missing, [.sleep, .healthPermissions])
        }
    }

    private func optionalActivity(at now: Date) async -> ActivityContext {
        (try? await health.activityContext(on: now, calendar: calendar)) ?? .missing
    }

    private func optionalSafetyFlags(at now: Date) async -> [SafetyFlag] {
        (try? await health.safetyFlags(on: now, calendar: calendar)) ?? []
    }

    private func loadRecovery(
        at now: Date,
        lastNightHours: Double?,
        sleepNeedHours: Double
    ) async -> RecoveryContext {
        guard let input = try? await health.recoveryInput(
            on: now,
            sleepLastNightHours: lastNightHours,
            sleepNeedHours: sleepNeedHours,
            calendar: calendar
        ) else {
            return .learning(days: 0)
        }
        return RecoveryEvaluator.evaluate(input)
    }

    private func sleepWithoutLastNight(_ sleep: SleepContext) -> SleepContext {
        SleepContext(
            lastNight: nil,
            coarseLabel: .unknown,
            shortfall7dMinutes: nil,
            nightsTracked: sleep.nightsTracked,
            wakeConsistency: sleep.wakeConsistency,
            bedtimePlan: sleep.bedtimePlan
        )
    }
}

