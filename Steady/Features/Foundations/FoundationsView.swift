import SteadyCore
import SwiftData
import SwiftUI

struct FoundationsView: View {
    @Environment(AppEnvironment.self) var environment
    @Environment(FoundationStore.self) var store
    @Environment(PlanStore.self) var planStore
    @Environment(\.modelContext) var context
    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) var scenePhase
    let profile: ProfileRecord
    let snapshot: PhaseOneContextSnapshot?
    @AppStorage("useSampleData") var sample = false
    @State var why: WhyItem?
    @State var showPermissionExplanation = false
    @State var permissionStatus = "Checking reminder access..."
    @State var mode: AlternativeMovementMode = .standing
    @State var avoids: Set<AlternativeMovement> = []
    @State var quiet: [NudgeQuietPeriod] = []
    @State var quietStart = 22 * 60
    @State var quietEnd = 8 * 60
    @State var requestingPermission = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    Text("Small options, not a daily checklist.").font(.title3.bold())
                    Text("Use what helps, change it, or leave it alone. No streak or completion target is tracked.")
                        .foregroundStyle(.secondary)
                    if sample { Text("Sample mode: reminders are simulated and never sent to your device.").font(.footnote) }
                    if let safety = store.safetyMessage {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(safety.title).font(.headline)
                            Text(safety.guidance)
                            Text(safety.emergencyGuidance).font(.footnote)
                        }.steadyCard()
                    }
                    preferences
                    reminders
                    if store.dayState != nil {
                        ForEach(FoundationKind.allCases, id: \.rawValue) { kind in foundationCard(kind) }
                    } else {
                        Button("Try loading Foundations again") { Task { await reload() } }
                    }
                    if let message = store.message { Text(message).font(.footnote).foregroundStyle(.secondary) }
                    if let failure = store.failure { Text(failure).foregroundStyle(.red) }
                    if let message = store.reminderMessage { Text(message).font(.footnote).foregroundStyle(.secondary) }
                }.padding()
            }
            .navigationTitle("Foundations")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .refreshable { await reload() }
        }
        .task(id: sample) { await reload() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await reload() } } }
        .onChange(of: planStore.safetyFlags) { _, flags in
            store.retainSafety(flags)
            Task { await refreshReminders() }
        }
        .sheet(item: $why) { WhySheet(title: $0.title, explanation: $0.explanation) }
        .alert("Optional quiet reminders", isPresented: $showPermissionExplanation) {
            Button("Continue") { Task { await requestReminderAccess() } }
            Button("Not now", role: .cancel) {}
        } message: {
            Text(sample
                 ? "Sample mode simulates permission and reminders without requesting or scheduling system notifications. The same daily limit and quiet-time rules apply. In-app cards remain available."
                 : "Steady uses on-device notifications only for optional Foundations. It considers at most three proactive reminders per Singapore day, respects quiet and sleep times, and reduces reminders you dismiss. In-app cards work without permission. Continue to review Apple's permission prompt.")
        }
        .disabled(store.isWorking || requestingPermission)
    }

    func reload() async {
        store.load(profile: profile, sample: sample, environment: environment, context: context)
        store.retainSafety(planStore.safetyFlags + planStore.sessionSafetyFlags)
        mode = store.settings.movementMode; avoids = store.settings.movementsToAvoid; quiet = store.quietPeriods
        await store.refreshSafety(profile: profile, sample: sample, environment: environment, additional: planStore.safetyFlags)
        await refreshReminders()
    }

    func refreshReminders() async {
        let requested = sample
        await FoundationReminderCoordinator.refresh(store: store, profile: profile, sample: requested,
            snapshot: snapshot, environment: environment, context: context)
        let access = await environment.notifications(useSampleData: requested).accessState()
        guard requested == sample else { return }
        switch access {
        case .notDetermined: permissionStatus = "Permission has not been requested. In-app cards remain available."
        case .denied: permissionStatus = "Notifications are off in system settings. Use quiet in-app cards, or change access in iPhone Settings."
        case .authorized: permissionStatus = "System access is available. Your reminder preference and quiet times still apply."
        }
    }

    func perform(_ action: FoundationAction, kind: FoundationKind, source: FoundationActionSource) {
        Task {
            if await store.act(action, kind: kind, source: source, profile: profile, sample: sample,
                               environment: environment, additionalSafety: planStore.safetyFlags, context: context) {
                await refreshReminders()
            }
        }
    }

    func requestReminderAccess() async {
        guard let source = store.source(profile: profile) else { return }
        let requested = sample
        requestingPermission = true
        defer { requestingPermission = false }
        do {
            let state = try await environment.notifications(useSampleData: requested).requestAccess()
            guard requested == sample else { return }
            try store.validate(source, profile: profile, sample: requested, environment: environment)
            if state == .authorized {
                _ = store.setNudgesEnabled(true, source: source, profile: profile, sample: requested,
                                          environment: environment, context: context)
            }
            await refreshReminders()
        } catch { store.failure = "Could not review notification access. In-app Foundations remain available." }
    }
}
