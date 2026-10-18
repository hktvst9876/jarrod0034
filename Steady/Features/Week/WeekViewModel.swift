import Foundation
import Observation
import SteadyCore
import SwiftData

@MainActor
@Observable
final class WeekViewModel {
    var summary: WeeklySummary?
    var review: WeeklyReview?
    var experiment: WeeklyExperiment?
    var defaultProposal: WeeklyDefaultProposal?
    var experimentDraft: WeeklyExperimentDraft?
    var reviewedDefault: WeeklyDefaultProposal?
    var helpfulness: WeeklyHelpfulness?
    var isLoading = false
    var failure: String?
    var message: String?
    var sleepNote = "Sleep context has not been read."
    @ObservationIgnored private var requestID = UUID()
    @ObservationIgnored private var lifecycleRevision: Int?
    @ObservationIgnored private var loadedAt: Date?
    @ObservationIgnored private var loadedWeekOffset = 0
    @ObservationIgnored private var pendingExperimentDraft: WeeklyExperimentDraft?
    @ObservationIgnored private var runtimeSleep: [WeeklySleepObservation] = []

    func invalidate() {
        requestID = UUID()
        summary = nil; defaultProposal = nil; experimentDraft = nil; reviewedDefault = nil
        review = nil; experiment = nil; helpfulness = nil; isLoading = false
        loadedAt = nil; pendingExperimentDraft = nil
        runtimeSleep = []
    }

    func load(profile: ProfileRecord, sample: Bool, weekOffset: Int, environment: AppEnvironment,
              context: ModelContext) async {
        invalidate()
        guard !environment.dataLifecycle.isBlocked, !MainActorDataAccessGate.isBlocked else { return }
        let operation = requestID
        let lifecycle = environment.dataLifecycle.revision
        lifecycleRevision = lifecycle
        let now = environment.now
        guard let date = environment.calendar.date(byAdding: .day, value: weekOffset * 7, to: now),
              let window = WeeklyWindow.make(containing: date, now: now, calendar: environment.calendar) else { return }
        isLoading = true; failure = nil
        defer { if requestID == operation { isLoading = false } }
        do {
            let stored = try WeeklyEvidenceLoader.read(profile: profile, sample: sample, window: window, container: context.container)
            guard let queryStart = environment.calendar.date(byAdding: .day, value: -1, to: window.start),
                  window.observedThrough > queryStart else { throw WeeklyReadError.invalidRecord }
            let samples: [SleepSample]
            let note: String
            do {
                samples = try await environment.health(useSampleData: sample).sleepSamples(
                    in: DateInterval(start: queryStart, end: window.observedThrough))
                note = sample ? "Illustrative sample sleep, not your Health history." : "Readable Health sleep only; missing or withheld nights remain unknown."
            } catch {
                samples = []
                note = "Health sleep is unavailable. Local records remain useful; no missing night becomes zero."
            }
            guard requestID == operation, !Task.isCancelled, !environment.dataLifecycle.isBlocked,
                  !MainActorDataAccessGate.isBlocked, environment.dataLifecycle.revision == lifecycle,
                  environment.calendar.isDate(now, inSameDayAs: environment.now),
                  let currentWindow = selectedWindow(weekOffset: weekOffset, environment: environment),
                  currentWindow.start == window.start else { return }
            let displayAt = environment.now
            guard let displayWindow = WeeklyWindow.make(containing: window.start, now: displayAt, calendar: environment.calendar) else {
                throw WeeklyReadError.staleContext
            }
            let fresh = try WeeklyEvidenceLoader.read(profile: profile, sample: sample, window: displayWindow, container: context.container)
            guard fresh.scope == stored.scope else { throw WeeklyReadError.staleContext }
            let sleep = SleepAggregator.nights(endingOn: environment.calendar.date(byAdding: .day, value: 6, to: window.start) ?? window.start,
                count: 7, samples: samples, calendar: environment.calendar).map {
                WeeklySleepObservation(id: "sleep-\($0.wakeDay.timeIntervalSinceReferenceDate)", day: $0.wakeDay,
                    actualMinutes: Double($0.asleepMinutes), opportunityMinutes: $0.inBedMinutes.map(Double.init),
                    source: sample ? .sample : .health)
            }
            let value = makeSummary(stored: fresh, window: displayWindow, sleep: sleep, calendar: environment.calendar)
            let key = WeeklyEvidenceLoader.key(profileID: profile.id, sample: sample, week: window.start)
            let defaultID = "weekly-default-" + key
            sleepNote = note
            runtimeSleep = sleep
            summary = value; review = fresh.review; helpfulness = fresh.review?.helpfulness; experiment = fresh.experiment
            loadedAt = displayAt; loadedWeekOffset = weekOffset
            defaultProposal = sample ? nil : WeeklyDefaultEngine.proposal(id: defaultID, summary: value,
                currentExamMode: profile.examMode, now: displayAt, calendar: environment.calendar)
        } catch {
            guard requestID == operation else { return }
            summary = nil
            failure = "This week's records changed or could not be read. Refresh before reviewing or saving anything; unavailable data is not zero."
        }
    }

    /// Called by the actual lazy List offer button, not by loading below-fold content.
    func recordVisibleSuggestion(_ kind: WeekVisibleSuggestion, profile: ProfileRecord, sample: Bool,
                                 environment: AppEnvironment, context: ModelContext) {
        do {
            let stored = try current(profile: profile, sample: sample, environment: environment, context: context)
            let at = environment.now
            let key = WeeklyEvidenceLoader.key(profileID: profile.id, sample: sample, week: stored.scope.weekStart)
            let subject: String
            switch kind {
            case .experiment:
                guard stored.experiment == nil || (stored.experiment?.endExclusive ?? at) <= at else { return }
                subject = "weekly-experiment-" + key
            case .lighterDefault:
                guard !sample, defaultProposal != nil else { return }
                subject = "weekly-default-" + key
            }
            guard try recordShown(subject: subject, profile: profile, sample: sample, at: at, container: context.container) else { return }
            guard let window = WeeklyWindow.make(containing: stored.scope.weekStart, now: at, calendar: environment.calendar) else {
                throw WeeklyReadError.staleContext
            }
            let tracked = try WeeklyEvidenceLoader.read(profile: profile, sample: sample, window: window, container: context.container)
            let value = makeSummary(stored: tracked, window: window, sleep: runtimeSleep, calendar: environment.calendar)
            // A newly visible exposure changes the evidence revision. Never retain an old confirmation.
            experimentDraft = nil; pendingExperimentDraft = nil; reviewedDefault = nil
            summary = value
            defaultProposal = sample ? nil : WeeklyDefaultEngine.proposal(id: "weekly-default-" + key, summary: value,
                currentExamMode: profile.examMode, now: at, calendar: environment.calendar)
        } catch {
            failure = "This suggestion's local exposure could not be recorded. Refresh before approving a change."
            experimentDraft = nil; pendingExperimentDraft = nil; reviewedDefault = nil; defaultProposal = nil
        }
    }

    func prepareExperiment(kind: WeeklyExperimentKind, start: Date, end: Date, environment: AppEnvironment) {
        guard let summary, !environment.dataLifecycle.isBlocked, !MainActorDataAccessGate.isBlocked else { return }
        pendingExperimentDraft = WeeklyExperimentDraft(id: UUID().uuidString, scope: summary.scope, kind: kind,
            start: environment.calendar.startOfDay(for: start), endExclusive: environment.calendar.startOfDay(for: end), preparedAt: environment.now)
    }

    func experimentEditorDismissed() {
        experimentDraft = pendingExperimentDraft
        pendingExperimentDraft = nil
    }

    func saveReview(profile: ProfileRecord, sample: Bool, environment: AppEnvironment, context: ModelContext) -> Bool {
        do {
            let stored = try current(profile: profile, sample: sample, environment: environment, context: context)
            let key = WeeklyEvidenceLoader.key(profileID: profile.id, sample: sample, week: stored.scope.weekStart)
            let value = WeeklyReview(id: key, scope: stored.scope, reviewedAt: environment.now, helpfulness: helpfulness)
            let transaction = ModelContext(context.container); transaction.autosaveEnabled = false
            do {
                let row = try transaction.fetch(FetchDescriptor<WeeklyReviewRecord>(predicate: #Predicate { $0.key == key })).first
                if let row { row.reviewData = try JSONEncoder().encode(value); row.updatedAt = environment.now }
                else { transaction.insert(try WeeklyReviewRecord(key: key, review: value, at: environment.now)) }
                if let helpfulness {
                    try writeMetric(WeeklyMetricEvent(id: "helpfulness-" + key, at: environment.now, kind: .helpfulness,
                        subjectID: "weekly-review-" + key, helpfulness: helpfulness), profile: profile, sample: sample, context: transaction, replace: true)
                } else {
                    let metricID = "helpfulness-" + key
                    for metric in try transaction.fetch(FetchDescriptor<WeeklyMetricRecord>(predicate: #Predicate { $0.id == metricID })) {
                        guard metric.profileID == profile.id, metric.sampleData == sample else { throw WeeklyReadError.invalidRecord }
                        transaction.delete(metric)
                    }
                }
                try transaction.save()
                review = value; message = "Review saved on this device. No default, plan, or reminder changed. Refresh to see the updated local summary."
                defaultProposal = nil; experimentDraft = nil; reviewedDefault = nil
                return true
            } catch { transaction.rollback(); throw error }
        } catch { return fail() }
    }

    func confirmExperiment(profile: ProfileRecord, sample: Bool, environment: AppEnvironment, context: ModelContext) -> Bool {
        guard let draft = experimentDraft else { return false }
        do {
            let stored = try current(profile: profile, sample: sample, environment: environment, context: context)
            let value = try WeeklyExperimentReducer.save(draft, currentScope: stored.scope, existing: stored.experiment,
                now: environment.now, calendar: environment.calendar)
            let weekKey = WeeklyEvidenceLoader.key(profileID: profile.id, sample: sample, week: stored.scope.weekStart)
            let key = weekKey + "-" + value.id
            let transaction = ModelContext(context.container); transaction.autosaveEnabled = false
            do {
                guard try transaction.fetch(FetchDescriptor<WeeklyExperimentRecord>(predicate: #Predicate { $0.key == key })).isEmpty else {
                    throw WeeklyReadError.staleContext
                }
                transaction.insert(try WeeklyExperimentRecord(key: key, experiment: value, at: environment.now))
                try accepted(subject: "weekly-experiment-" + weekKey, stored: stored, profile: profile, sample: sample,
                    at: environment.now, context: transaction)
                try transaction.save()
                experiment = value; experimentDraft = nil; defaultProposal = nil
                message = "Your experiment is saved locally. It changes no plan, reminder, or default; the measure is your next review."
                return true
            } catch { transaction.rollback(); throw error }
        } catch { return fail() }
    }

    func confirmDefault(profile: ProfileRecord, sample: Bool, environment: AppEnvironment, context: ModelContext) -> Bool {
        guard !sample, let proposal = reviewedDefault else { return false }
        do {
            let stored = try current(profile: profile, sample: sample, environment: environment, context: context)
            let transaction = ModelContext(context.container); transaction.autosaveEnabled = false
            do {
                let id = profile.id
                guard let savedProfile = try transaction.fetch(FetchDescriptor<ProfileRecord>(predicate: #Predicate { $0.id == id })).first,
                      savedProfile.domainProfile() == profile.domainProfile() else { throw WeeklyReadError.staleContext }
                let priorIDs = Set(stored.metrics.filter { $0.kind == .suggestionAccepted }.map(\.subjectID))
                let result = try WeeklyApprovalReducer.confirm(proposal, currentScope: stored.scope,
                    currentExamMode: savedProfile.examMode, appliedProposalIDs: priorIDs,
                    now: environment.now, calendar: environment.calendar)
                if case .applyExamMode(let enabled) = result { savedProfile.examMode = enabled }
                try accepted(subject: proposal.id, stored: stored, profile: profile, sample: sample, at: environment.now, context: transaction)
                try transaction.save()
                profile.examMode = savedProfile.examMode
                reviewedDefault = nil; defaultProposal = nil; experimentDraft = nil
                message = "Exam mode was enabled after your approval. It keeps planning lighter and does not raise exercise targets."
                return true
            } catch { transaction.rollback(); throw error }
        } catch { return fail() }
    }

    private func current(profile: ProfileRecord, sample: Bool, environment: AppEnvironment, context: ModelContext) throws -> WeeklyStoredEvidence {
        guard !environment.dataLifecycle.isBlocked, !MainActorDataAccessGate.isBlocked,
              lifecycleRevision == environment.dataLifecycle.revision, let summary,
              summary.scope.profileID == profile.id, summary.scope.isSample == sample, let loadedAt,
              environment.now.timeIntervalSince(loadedAt) >= 0, environment.now.timeIntervalSince(loadedAt) <= 1_800,
              environment.calendar.isDate(loadedAt, inSameDayAs: environment.now),
              selectedWindow(weekOffset: loadedWeekOffset, environment: environment)?.start == summary.window.start,
              let currentWeek = WeeklyWindow.make(containing: summary.window.start, now: environment.now, calendar: environment.calendar) else {
            throw WeeklyReadError.staleContext
        }
        let stored = try WeeklyEvidenceLoader.read(profile: profile, sample: sample, window: currentWeek, container: context.container)
        guard stored.scope == summary.scope else { throw WeeklyReadError.staleContext }
        return stored
    }

    private func makeSummary(stored: WeeklyStoredEvidence, window: WeeklyWindow, sleep: [WeeklySleepObservation], calendar: Calendar) -> WeeklySummary {
        WeeklyAggregator.summarize(WeeklyInput(scope: stored.scope, window: window, sleep: sleep,
            movement: stored.movement, plans: stored.plans, choices: stored.choices, foundations: stored.foundations,
            foodCorrections: stored.foods, metrics: stored.metrics), calendar: calendar)
    }

    private func selectedWindow(weekOffset: Int, environment: AppEnvironment) -> WeeklyWindow? {
        guard let date = environment.calendar.date(byAdding: .day, value: weekOffset * 7, to: environment.now) else { return nil }
        return WeeklyWindow.make(containing: date, now: environment.now, calendar: environment.calendar)
    }

    private func recordShown(subject: String, profile: ProfileRecord, sample: Bool, at: Date, container: ModelContainer) throws -> Bool {
        let transaction = ModelContext(container); transaction.autosaveEnabled = false
        do {
            let id = "shown-" + subject
            if let row = try transaction.fetch(FetchDescriptor<WeeklyMetricRecord>(predicate: #Predicate { $0.id == id })).first {
                let event = try JSONDecoder().decode(WeeklyMetricEvent.self, from: row.eventData)
                guard row.profileID == profile.id, row.sampleData == sample,
                      event.kind == .suggestionShown, event.subjectID == subject else { throw WeeklyReadError.invalidRecord }
                return false
            }
            try writeMetric(WeeklyMetricEvent(id: "shown-" + subject, at: at, kind: .suggestionShown, subjectID: subject),
                profile: profile, sample: sample, context: transaction)
            try transaction.save()
            return true
        } catch { transaction.rollback(); throw error }
    }

    private func accepted(subject: String, stored: WeeklyStoredEvidence, profile: ProfileRecord, sample: Bool,
                          at: Date, context: ModelContext) throws {
        let shown = stored.metrics.filter { $0.kind == .suggestionShown && $0.subjectID == subject }.min { $0.at < $1.at }
        let seconds = shown.flatMap { exposure -> Double? in
            let value = at.timeIntervalSince(exposure.at)
            return value.isFinite && (0...86_400).contains(value) ? value : nil
        }
        try writeMetric(WeeklyMetricEvent(id: "accepted-" + subject, at: at, kind: .suggestionAccepted,
            subjectID: subject, decisionSeconds: seconds), profile: profile, sample: sample, context: context)
    }

    private func writeMetric(_ event: WeeklyMetricEvent, profile: ProfileRecord, sample: Bool, context: ModelContext, replace: Bool = false) throws {
        let id = event.id
        if let row = try context.fetch(FetchDescriptor<WeeklyMetricRecord>(predicate: #Predicate { $0.id == id })).first {
            guard row.profileID == profile.id, row.sampleData == sample else { throw WeeklyReadError.invalidRecord }
            if replace { row.eventData = try JSONEncoder().encode(event); row.at = event.at }
        } else { context.insert(try WeeklyMetricRecord(event: event, profileID: profile.id, sampleData: sample)) }
    }

    private func fail() -> Bool {
        failure = "Nothing was applied. This review changed, expired, or could not be saved. Refresh and explicitly review it again."
        experimentDraft = nil; reviewedDefault = nil; defaultProposal = nil
        return false
    }
}

enum WeekVisibleSuggestion { case experiment, lighterDefault }
