import SwiftData
import SwiftUI

struct RootTabView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("useSampleData") private var sample = false
    let profile: ProfileRecord
    @State private var todayModel = TodayViewModel()
    @State private var planStore = PlanStore()
    @State private var foundationStore = FoundationStore()
    @State private var selectedTab = Tab.today
    @State private var showNotificationFoundations = false
    @State private var lastRoutedResponseID: String?
    @State private var watch = WatchPhoneCoordinator()
    @State private var presentedWatchHandoffID: String?

    private enum Tab: Hashable { case today, move, sleep, eat, week }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView(profile: profile, model: todayModel)
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(Tab.today)

            MoveView(profile: profile, todayModel: todayModel)
                .tabItem { Label("Move", systemImage: "figure.walk") }
                .tag(Tab.move)

            SleepView(profile: profile)
                .tabItem { Label("Sleep", systemImage: "moon.stars") }
                .tag(Tab.sleep)

            EatView(profile: profile)
                .tabItem { Label("Eat", systemImage: "fork.knife") }
                .tag(Tab.eat)

            WeekView(profile: profile, isSelected: selectedTab == .week)
                .tabItem { Label("Week", systemImage: "calendar") }
                .tag(Tab.week)
        }
        .tint(.teal)
        .environment(planStore)
        .environment(foundationStore)
        .onDisappear { watch.invalidate() }
        .task { await handleNotificationInbox(); await refreshWatch() }
        .task(id: scenePhase) {
            guard scenePhase == .active else { watch.invalidate(); return }
            watch.requestRepublish()
            await refreshWatch()
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                guard scenePhase == .active, !Task.isCancelled else { return }
                await refreshWatch()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await handleNotificationInbox() } }
        }
        .onReceive(NotificationCenter.default.publisher(for: .foundationNotificationResponse)) { _ in
            Task { await handleNotificationInbox() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .companionInboxChanged)) { _ in
            Task { await refreshWatch() }
        }
        .onChange(of: foundationStore.openFoundationsRequested) { _, requested in
            if requested { presentNotificationFoundations() }
        }
        .onChange(of: todayModel.showMorningCheckIn) { _, value in
            if value && showNotificationFoundations { todayModel.showMorningCheckIn = false }
        }
        .sheet(isPresented: $showNotificationFoundations) {
            FoundationsView(profile: profile, snapshot: todayModel.snapshot)
        }
        .sheet(item: $watch.handoff, onDismiss: { dismissWatchHandoff() }) { route in
            WatchSavedMealHandoffView(route: route) { dismissWatchHandoff() }
        }
        .onChange(of: watch.handoff?.id) { _, id in
            if let id {
                presentedWatchHandoffID = id
                selectedTab = .eat
                todayModel.showMorningCheckIn = false
                showNotificationFoundations = false
            }
        }
        .safeAreaInset(edge: .bottom) {
            if let message = watch.message {
                DisclosureGroup("Watch sync") {
                    Text(message).font(.caption)
                    Button("Refresh Watch sync") {
                        watch.requestRepublish()
                        Task { await refreshWatch() }
                    }.font(.caption)
                }
                .font(.caption).padding(.horizontal).padding(.vertical, 4).background(.regularMaterial)
            }
        }
        .onChange(of: sample) { _, value in
            watch.invalidate()
            Task {
                // Stop real pending delivery before any context read in sample mode.
                if value { await environment.notifications(useSampleData: false).cancelAll() }
                await refreshReminders()
                await refreshWatch()
            }
        }
        .onChange(of: planStore.plan) { _, _ in
            watch.invalidate()
            Task { await refreshReminders(); await refreshWatch() }
        }
        .onChange(of: planStore.record?.startedAt) { _, _ in Task { await refreshReminders() } }
        .onChange(of: planStore.safetyFlags) { _, flags in
            watch.invalidate()
            foundationStore.retainSafety(flags)
            Task { await refreshReminders(); await refreshWatch() }
        }
        .onChange(of: profile.domainProfile()) { _, _ in watchContextChanged() }
        .onChange(of: profile.movementsToAvoid) { _, _ in watchContextChanged() }
        .onChange(of: todayModel.priority) { _, _ in watchContextChanged() }
        .onChange(of: planStore.hasLoaded) { _, _ in watchContextChanged() }
        .onChange(of: foundationStore.dayState) { _, _ in watchContextChanged() }
        .onChange(of: foundationStore.revision) { _, _ in watchContextChanged() }
    }

    private func watchContextChanged() {
        watch.invalidate()
        Task { await refreshReminders(); await refreshWatch() }
    }

    private func refreshWatch() async {
        guard scenePhase == .active else { return }
        let capturedProfileID = profile.id
        let capturedSample = sample
        await watch.refresh(profile: profile, sample: capturedSample, today: todayModel, plans: planStore,
            foundations: foundationStore, environment: environment, context: context,
            requestIsCurrent: { scenePhase == .active && profile.id == capturedProfileID && sample == capturedSample })
    }

    private func dismissWatchHandoff() {
        guard let id = presentedWatchHandoffID else { return }
        watch.dismissHandoff(id: id, profile: profile, sample: sample, environment: environment, context: context)
        presentedWatchHandoffID = nil
    }

    private func refreshReminders() async {
        await FoundationReminderCoordinator.refresh(store: foundationStore, profile: profile, sample: sample,
            snapshot: todayModel.snapshot, environment: environment, context: context)
    }

    private func handleNotificationInbox() async {
        guard scenePhase == .active, !sample else { return }
        let responses = FoundationNotificationInbox.shared.responses().filter { $0.profileID == profile.id }
        guard !responses.isEmpty else { return }
        foundationStore.load(profile: profile, sample: false, environment: environment, context: context)
        foundationStore.retainSafety(planStore.safetyFlags + planStore.sessionSafetyFlags)
        if let response = responses.last(where: { $0.action != .dismiss }), response.id != lastRoutedResponseID {
            lastRoutedResponseID = response.id
            presentNotificationFoundations()
        }
        await refreshReminders()
    }

    private func presentNotificationFoundations() {
        selectedTab = .today
        todayModel.showMorningCheckIn = false
        foundationStore.openFoundationsRequested = false
        showNotificationFoundations = true
    }
}

