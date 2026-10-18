import SteadyCore
import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(AppEnvironment.self) var environment
    @Environment(\.modelContext) var modelContext
    @Environment(PlanStore.self) var planStore
    @Environment(FoundationStore.self) var foundationStore
    @Environment(\.scenePhase) var scenePhase
    let profile: ProfileRecord
    @Bindable var model: TodayViewModel
    @State var why: WhyItem?
    @State var showSettings = false
    @State var showSafetyChoices = false
    @State var showPriorityChoices = false
    @State var saveError: String?
    @State var showAlternatives = false
    @State var showFoundations = false
    @State var showClearCalendarRetry = false
    @State var pendingRetryOperationID: String?
    @AppStorage("useSampleData") var useSampleData = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if model.isLoading && model.priority == nil {
                        ProgressView("Building a calm plan...")
                            .padding(.top, 80)
                    } else {
                        priorityCard
                        pendingCalendarRecovery
                        foundationsCard
                        if let message = planStore.message { Text(message).font(.footnote).foregroundStyle(.secondary) }
                        if let failure = planStore.failure { Text(failure).foregroundStyle(.red) }
                        contextCards
                        fallbackCard
                        safetyButton
                    }
                }
                .padding()
            }
            .navigationTitle(greeting)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape") { showSettings = true }
                }
            }
            .refreshable { await reload() }
        }
        .task(id: useSampleData) { await reload() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await reload() } } }
        .onChange(of: profile.lowDataMode) { _, _ in why = nil }
        .sheet(isPresented: $showSettings, onDismiss: { Task { await reload() } }) {
            NavigationStack { SettingsView(profile: profile) }
        }
        .sheet(isPresented: $model.showMorningCheckIn) {
            MorningCheckInSheet { saveCheckIn($0) }
                .interactiveDismissDisabled()
        }
        .sheet(item: $why) { item in
            WhySheet(title: item.title, explanation: item.explanation)
        }
        .sheet(isPresented: $showPriorityChoices) {
            PriorityPickerSheet { kind in
                model.choosePriority(kind, profile: profile, now: environment.now, calendar: environment.calendar)
                planStore.suggestedPlan = model.priority?.planA
                if let priority = model.priority {
                    Task { await planStore.replacePriority(priority.planA, profile: profile, sample: useSampleData,
                        environment: environment, context: modelContext) }
                }
                showPriorityChoices = false
            }
        }
        .sheet(isPresented: $showAlternatives) {
            if let source = planStore.effectivePlan(priority: model.priority) {
                AlternativesView(profile: profile, source: source, snapshot: model.snapshot)
            }
        }
        .sheet(isPresented: $showFoundations) { FoundationsView(profile: profile, snapshot: model.snapshot) }
        .confirmationDialog("Pause exercise advice for today?", isPresented: $showSafetyChoices) {
            ForEach(Symptom.allCases, id: \.rawValue) { symptom in
                Button(symptom.title) {
                    saveSymptom(symptom)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Choose only something you are experiencing. Steady does not infer symptoms.")
        }
        .alert("Could not save your check-in", isPresented: saveErrorIsPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "Please try again.")
        }
    }


    @ViewBuilder
    var contextCards: some View {
        if let snapshot = model.snapshot {
            TodaySleepCard(sleep: snapshot.sleep, lowDataMode: profile.lowDataMode, why: $why) {
                model.ignoreSleepForPriority = true
                Task { await reload() }
            }
            TodayActivityCard(activity: snapshot.activity, why: $why)
            if profile.lowDataMode {
                Text("Recovery labels are hidden by low-data mode.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TodayRecoveryCard(recovery: snapshot.recovery, why: $why)
            }
        }
    }

    @ViewBuilder
    var fallbackCard: some View {
        if model.snapshot?.availability.source == .unknown
            || model.snapshot?.availability.source == .manualMinutes {
            VStack(alignment: .leading, spacing: 10) {
                Text("How much free time do you have today?").font(.headline)
                Picker("Available time", selection: $model.manualFreeMinutes) {
                    Text("Choose").tag(Int?.none)
                    Text("15 min").tag(Int?.some(15))
                    Text("30 min").tag(Int?.some(30))
                    Text("60 min").tag(Int?.some(60))
                }
                Button("Use this availability") { Task { await reload() } }
                    .buttonStyle(.borderedProminent)
                Button("Why Steady asks") {
                    why = WhyItem(
                        title: "Available time",
                        explanation: "When Calendar is unavailable, your estimate stops Steady suggesting a plan that cannot fit."
                    )
                }
                .font(.footnote)
            }
            .steadyCard()
        }
    }

    var safetyButton: some View {
        Button {
            showSafetyChoices = true
        } label: {
            Label("Report pain or a concerning symptom", systemImage: "cross.case")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .tint(.primary)
    }

    var greeting: String {
        profile.name.isEmpty ? "Today" : "Hi, \(profile.name)"
    }


    var saveErrorIsPresented: Binding<Bool> {
        Binding(get: { saveError != nil }, set: { if !$0 { saveError = nil } })
    }
}

struct WhyItem: Identifiable {
    let id = UUID()
    let title: String
    let explanation: String
}

extension View {
    func steadyCard() -> some View {
        self
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}
