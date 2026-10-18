import Foundation
import Observation
import SteadyCore

@MainActor
@Observable
final class TodayViewModel {
    var snapshot: PhaseOneContextSnapshot?
    var priority: DailyPriority?
    var isLoading = false
    var showMorningCheckIn = false
    var ignoreSleepForPriority = false
    var manualFreeMinutes: Int?
    var userSelectedPriority: PriorityKind?
    var reportedSymptoms: [Symptom] = []
    private var lastLoadedDay: Date?
    private var loadRequestID = UUID()
    private var loadedSampleMode: Bool?

    func load(profile record: ProfileRecord, environment: AppEnvironment, useSampleData: Bool,
              requestIsCurrent: () -> Bool = { true }) async -> Bool {
        let privacyRevision = DataDeletionGate.shared.revision
        guard !DataDeletionGate.shared.isBlocked, let profile = record.domainProfile() else { return false }
        let requestID = UUID()
        loadRequestID = requestID
        let loadedDay = environment.calendar.startOfDay(for: environment.now)
        if loadedSampleMode != useSampleData || lastLoadedDay != loadedDay {
            snapshot = nil
            priority = nil
        }
        if lastLoadedDay != loadedDay {
            ignoreSleepForPriority = false
            manualFreeMinutes = nil
            userSelectedPriority = nil
            reportedSymptoms = []
        }
        lastLoadedDay = loadedDay
        isLoading = true
        defer { if loadRequestID == requestID { isLoading = false } }
        let loader = PhaseOneContextLoader(
            health: environment.health(useSampleData: useSampleData),
            calendarProvider: environment.calendar(useSampleData: useSampleData),
            calendar: environment.calendar
        )
        let loaded = await loader.load(
            at: environment.now,
            profile: profile,
            ignoreLastNightSleep: ignoreSleepForPriority,
            manualFreeMinutes: manualFreeMinutes
        )
        guard !DataDeletionGate.shared.isBlocked, privacyRevision == DataDeletionGate.shared.revision,
              loadRequestID == requestID, !Task.isCancelled, requestIsCurrent(),
              record.domainProfile() == profile,
              environment.calendar.startOfDay(for: environment.now) == loadedDay else { return false }
        snapshot = loaded
        loadedSampleMode = useSampleData
        priority = makePriority(
            snapshot: loaded,
            profile: profile,
            record: record,
            now: environment.now,
            calendar: environment.calendar
        )
        showMorningCheckIn = shouldOfferCheckIn(record: record, profile: profile, now: environment.now, calendar: environment.calendar)
        return true
    }

    func updatePriority(profile record: ProfileRecord, now: Date, calendar: Calendar) {
        guard let snapshot, let profile = record.domainProfile() else { return }
        priority = makePriority(
            snapshot: snapshot,
            profile: profile,
            record: record,
            now: now,
            calendar: calendar
        )
    }

    func report(_ symptom: Symptom, profile: ProfileRecord, now: Date, calendar: Calendar) {
        if !reportedSymptoms.contains(symptom) {
            reportedSymptoms.append(symptom)
        }
        updatePriority(profile: profile, now: now, calendar: calendar)
    }

    func choosePriority(_ kind: PriorityKind?, profile: ProfileRecord, now: Date, calendar: Calendar) {
        userSelectedPriority = kind
        updatePriority(profile: profile, now: now, calendar: calendar)
    }

    private func makePriority(
        snapshot: PhaseOneContextSnapshot,
        profile: Profile,
        record: ProfileRecord,
        now: Date,
        calendar: Calendar
    ) -> DailyPriority {
        let checkIn = checkIn(for: record, on: now, calendar: calendar)
        var symptoms = reportedSymptoms
        if let date = record.reportedSafetySymptomAt,
           calendar.isDate(date, inSameDayAs: now),
           let rawValue = record.reportedSafetySymptomRawValue,
           let stored = Symptom(rawValue: rawValue),
           !symptoms.contains(stored) {
            symptoms.append(stored)
        }
        let flags = snapshot.safetyFlags + symptoms.map { .userReported($0) }
        let context = DailyContext(
            date: now,
            sleep: snapshot.sleep,
            sleepNeedMinutes: profile.sleep.sleepNeedMinutes,
            recovery: snapshot.recovery,
            activity: snapshot.activity,
            availability: snapshot.availability,
            checkIn: checkIn,
            safetyFlags: flags,
            plannedToday: nil,
            strengthDoneThisWeek: 0,
            strengthTarget: 0,
            daysLeftInWeekIncludingToday: daysLeftInWeek(from: now, calendar: calendar),
            strengthYesterday: false,
            plannedStrengthDay: false,
            preferredWorkoutPeriod: profile.movement.preferredWorkoutTime,
            examMode: profile.examMode,
            preferredFallbackFocus: profile.primaryFocus,
            userSelectedPriority: userSelectedPriority,
            dataGaps: snapshot.dataGaps
        )
        return DailyPriorityEngine.select(for: context)
    }

    private func checkIn(for record: ProfileRecord, on now: Date, calendar: Calendar) -> CheckIn? {
        guard let date = record.lastMorningCheckInAt,
              calendar.isDate(date, inSameDayAs: now),
              let rawValue = record.lastMorningCheckInRawValue else {
            return nil
        }
        return CheckIn(rawValue: rawValue)
    }

    private func shouldOfferCheckIn(
        record: ProfileRecord,
        profile: Profile,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        if let previous = record.lastMorningCheckInAt, calendar.isDate(previous, inSameDayAs: now) {
            return false
        }
        let weekday = calendar.component(.weekday, from: now)
        let wake = weekday == 1 || weekday == 7
            ? profile.sleep.weekendWakeTime
            : profile.sleep.weekdayWakeTime
        guard let wakeToday = wake.date(on: now, calendar: calendar) else { return false }
        return now >= wakeToday
    }

    private func daysLeftInWeek(from date: Date, calendar: Calendar) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        let mondayBasedWeekday = ((weekday + 5) % 7) + 1
        return 8 - mondayBasedWeekday
    }
}

