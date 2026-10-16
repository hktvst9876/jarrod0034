import SteadyCore
import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var modelContext
    let profile: ProfileRecord
    @State private var model = TodayViewModel()
    @State private var why: WhyItem?
    @State private var showSettings = false
    @State private var showSafetyChoices = false
    @State private var showPriorityChoices = false
    @State private var saveError: String?
    @AppStorage("useSampleData") private var useSampleData = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if model.isLoading && model.priority == nil {
                        ProgressView("Building a calm plan…")
                            .padding(.top, 80)
                    } else {
                        priorityCard
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
                showPriorityChoices = false
            }
        }
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
    private var priorityCard: some View {
        if let priority = model.priority {
            VStack(alignment: .leading, spacing: 12) {
                Text("TODAY'S PRIORITY").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Text(priority.title).font(.title2.bold())
                Text(priority.explanation.summary).foregroundStyle(.secondary)
                Divider()
                Label(priority.planA.title, systemImage: "arrow.right.circle.fill").font(.headline)
                if priority.planA.minutes > 0 {
                    Button("About \(priority.planA.minutes) minutes - Why") {
                        why = WhyItem(
                            title: "Why this amount",
                            explanation: "This is the useful version chosen by today's priority rule. You can choose another priority at any time."
                        )
                    }
                    .font(.subheadline)
                }
                if let slot = priority.planA.slot {
                    Button("Proposed time: \(slot.start.formatted(date: .omitted, time: .shortened)) - Why") {
                        why = WhyItem(
                            title: "Proposed time",
                            explanation: "This time fits a free window without using the part of the evening protected for sleep. It has not been added to Calendar."
                        )
                    }
                    .font(.subheadline)
                }
                Button("Why this priority") {
                    why = WhyItem(title: priority.title, explanation: priority.explanation.summary)
                }
                Button("Choose another priority") { showPriorityChoices = true }
                    .buttonStyle(.bordered)
            }
            .steadyCard()
        }
    }

    @ViewBuilder
    private var contextCards: some View {
        if let snapshot = model.snapshot {
            TodaySleepCard(sleep: snapshot.sleep, why: $why) {
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
    private var fallbackCard: some View {
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

    private var safetyButton: some View {
        Button {
            showSafetyChoices = true
        } label: {
            Label("Report pain or a concerning symptom", systemImage: "cross.case")
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.bordered)
        .tint(.primary)
    }

    private var greeting: String {
        profile.name.isEmpty ? "Today" : "Hi, \(profile.name)"
    }

    private func reload() async {
        await model.load(profile: profile, environment: environment, useSampleData: useSampleData)
    }

    private func saveCheckIn(_ checkIn: CheckIn) {
        profile.lastMorningCheckInAt = environment.now
        profile.lastMorningCheckInRawValue = checkIn.rawValue
        do {
            try modelContext.save()
            model.showMorningCheckIn = false
            model.updatePriority(profile: profile, now: environment.now, calendar: environment.calendar)
        } catch {
            modelContext.rollback()
            saveError = error.localizedDescription
        }
    }

    private func saveSymptom(_ symptom: Symptom) {
        profile.reportedSafetySymptomAt = environment.now
        profile.reportedSafetySymptomRawValue = symptom.rawValue
        do {
            try modelContext.save()
        } catch {
            saveError = error.localizedDescription
        }
        model.report(symptom, profile: profile, now: environment.now, calendar: environment.calendar)
    }

    private var saveErrorIsPresented: Binding<Bool> {
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
