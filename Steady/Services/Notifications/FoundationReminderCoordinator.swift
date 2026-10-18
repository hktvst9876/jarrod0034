import Foundation
import SteadyCore
import SwiftData

@MainActor
enum FoundationReminderCoordinator {
    private struct Request {
        let store: FoundationStore
        let profile: ProfileRecord
        let sample: Bool
        let snapshot: PhaseOneContextSnapshot?
        let environment: AppEnvironment
        let context: ModelContext
        let privacyRevision: Int
    }
    private static var working = false
    private static var next: Request?

    /// Serialize replacements; an overlapping foreground refresh is processed last.
    static func refresh(store: FoundationStore, profile: ProfileRecord, sample: Bool,
                        snapshot: PhaseOneContextSnapshot?, environment: AppEnvironment, context: ModelContext) async {
        guard !DataDeletionGate.shared.isBlocked, store.dataAccessValid else { return }
        next = Request(store: store, profile: profile, sample: sample, snapshot: snapshot, environment: environment,
            context: context, privacyRevision: DataDeletionGate.shared.revision)
        guard !working else { return }
        working = true
        defer { working = false }
        while let request = next {
            next = nil
            await perform(request)
        }
    }

    private static func perform(_ request: Request) async {
        guard current(request) else { return }
        let store = request.store, environment = request.environment
        store.silentCards = []
        let profile = request.profile, sample = request.sample, context = request.context
        let provider = environment.notifications(useSampleData: sample)
        if sample { await environment.notifications(useSampleData: false).cancelAll() }
        guard current(request), sample == UserDefaults.standard.bool(forKey: "useSampleData"),
              store.isCurrent(profile: profile, sample: sample, environment: environment) else {
            await provider.cancelAll(); return
        }
        if !sample {
            for response in FoundationNotificationInbox.shared.responses() {
                guard current(request) else { return }
                if response.profileID != profile.id { continue }
                if await store.handleNotificationResponse(response, profile: profile, sample: sample, environment: environment, context: context) {
                    guard current(request) else { return }
                    FoundationNotificationInbox.shared.remove(id: response.id)
                }
            }
        }
        if !sample, let erased = DataDeletionGate.shared.currentErase,
           WeeklyResetNudgePolicy.shouldStayQuiet(erasedAt: erased.createdAt, now: environment.now, calendar: environment.calendar) {
            // Clearing old budget journals must not buy a second daily interruption allowance.
            await provider.cancelAll()
            guard current(request) else { return }
            store.reminderMessage = "After a local data reset, proactive reminders stay quiet until the next Singapore day. In-app Foundations remain available."
            return
        }
        let captured = store.source(profile: profile)
        let capturedProfile = profile.domainProfile()
        guard let state = store.dayState else { await provider.cancelAll(); return }
        do {
            let details = try await FoundationReminderContextLoader.load(profile: profile, sample: sample,
                environment: environment, snapshot: request.snapshot, context: context)
            guard current(request) else { return }
            await store.refreshSafety(profile: profile, sample: sample, environment: environment)
            guard current(request) else { return }
            let access = await provider.accessState()
            guard current(request), next == nil, sample == UserDefaults.standard.bool(forKey: "useSampleData"),
                  captured == store.source(profile: profile),
                  capturedProfile == profile.domainProfile(),
                  store.isCurrent(profile: profile, sample: sample, environment: environment) else {
                await provider.cancelAll(); return
            }
            guard let details, store.movementPreferencesConfirmed(profile: profile) else {
                await provider.cancelAll()
                store.reminderMessage = "Review your movement preferences. Foundations stay available without reminders."
                return
            }
            if !sample {
                try FoundationNotificationBudget.includeKnown(store.reservations, now: environment.now, calendar: environment.calendar)
            }
            let history = sample ? store.reservations : try FoundationNotificationBudget.history()
            let candidates = FoundationReminderCandidates.build(state: state, profileID: profile.id,
                context: details, reservations: history, calendar: environment.calendar)
            let planning = NudgePlanningContext(
                now: environment.now, day: state.day, calendar: environment.calendar,
                enabledKinds: Set(FoundationKind.allCases).subtracting(store.settings.disabledKinds),
                completedKinds: Set(state.items.filter { $0.status == .done }.map(\.kind)),
                quietPeriods: store.quietPeriods, calendarBlocks: details.calendarBlocks,
                workoutBlocks: details.workoutBlocks, sleepWindows: details.sleepWindows,
                dismissalCounts: store.dismissals, reservations: history,
                notificationPermission: store.nudgesEnabled && access == .authorized && details.schedulingContextAvailable,
                lowDataMode: profile.lowDataMode, safetyFlags: store.safetyFlags
            )
            let result = NudgePlanner.plan(candidates: candidates, context: planning)
            guard current(request) else { return }
            let reservations = result.notifications.map {
                NudgeReservation(id: $0.id, kind: $0.kind, day: state.day, fireAt: $0.fireAt)
            }
            try store.reserve(reservations, context: context)
            if !sample { try FoundationNotificationBudget.reserve(reservations, now: environment.now, calendar: environment.calendar) }
            let reminders = result.notifications.map { value in
                FoundationReminderRequest(id: value.id, profileID: profile.id, day: state.day, kind: value.kind,
                    optionID: state.items.first(where: { $0.kind == value.kind })?.optionID,
                    fireAt: value.fireAt, title: value.title, body: value.body, privacyRevision: request.privacyRevision)
            }
            try await provider.replace(reminders)
            if !current(request) || next != nil || sample != UserDefaults.standard.bool(forKey: "useSampleData")
                || captured != store.source(profile: profile)
                || capturedProfile != profile.domainProfile() { await provider.cancelAll(); return }
            store.silentCards = result.silentCards
            store.reminderMessage = sample ? "Sample reminders only. No system notifications are scheduled."
                : (!store.nudgesEnabled ? "Reminders are off. Use Foundations here whenever you choose."
                : (!details.schedulingContextAvailable ? "Calendar or sleep timing is unavailable. Foundations stay quiet in Today."
                : "Reminders follow your quiet periods, protected time, and daily limit. Other actions stay in Today."))
        } catch {
            await provider.cancelAll()
            guard current(request) else { return }
            store.reminderMessage = "Reminders could not be updated. Foundations remain available here. \(error.localizedDescription)"
        }
    }

    private static func current(_ request: Request) -> Bool {
        !DataDeletionGate.shared.isBlocked && request.privacyRevision == DataDeletionGate.shared.revision
            && request.store.dataAccessValid
    }
}
