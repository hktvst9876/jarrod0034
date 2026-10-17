import SteadyCore
import SwiftData
import SwiftUI

struct MoveView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(PlanStore.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    let profile: ProfileRecord
    let todayModel: TodayViewModel
    @AppStorage("useSampleData") private var sample = false
    @State private var showAlternatives = false
    @State private var why: WhyItem?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let safety = store.safetyMessage {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(safety.title).font(.title2.bold())
                            Text(safety.guidance)
                            Text(safety.emergencyGuidance).font(.footnote)
                        }.steadyCard()
                    } else if let plan = store.effectivePlan(priority: todayModel.priority) {
                        planCard(plan)
                    } else { ProgressView("Loading your plan...") }
                    if let message = store.message { Text(message).foregroundStyle(.secondary) }
                    if let failure = store.failure { Text(failure).foregroundStyle(.red) }
                    Text("Movement stays at a comfortable level. Stop if you have pain or a concerning symptom.")
                        .font(.footnote).foregroundStyle(.secondary)
                }.padding()
            }
            .navigationTitle("Move")
            .refreshable { await load() }
        }
        .task(id: sample) { await load() }
        .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await load() } } }
        .sheet(isPresented: $showAlternatives) {
            if let plan = store.effectivePlan(priority: todayModel.priority) {
                AlternativesView(profile: profile, source: plan, snapshot: todayModel.snapshot)
            }
        }
        .sheet(item: $why) { WhySheet(title: $0.title, explanation: $0.explanation) }
    }

    private func planCard(_ plan: PlanItem) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(plan.status.title).font(.subheadline).foregroundStyle(.secondary)
            Text(plan.title).font(.title2.bold())
            Text(plan.outcome.summary)
            if plan.minutes > 0 {
                Button("About \(plan.minutes) minutes - Why") {
                    why = WhyItem(title: "Plan duration", explanation: "This is the approximate duration of your current plan. You can choose a shorter alternative at any time.")
                }
            }
            if let option = store.selectedOption {
                ForEach(Array(option.steps.enumerated()), id: \.offset) { _, step in Text("- \(step)") }
            }
            if plan.status == .completed {
                Label("Saved as completed", systemImage: "checkmark.circle")
            } else if plan.status == .intentionallyRested {
                Label("Rest is the plan", systemImage: "leaf")
            } else {
                if isMovement(plan) {
                    if store.record?.startedAt == nil {
                        Button("Start this plan", systemImage: "play.fill") {
                            Task { await store.start(plan, profile: profile, sample: sample, environment: environment, context: context) }
                        }.buttonStyle(.borderedProminent)
                        .disabled(!profile.movementsToAvoid.isEmpty && store.record?.movementNoteAtChoice != profile.movementsToAvoid)
                    } else {
                        Text("In progress. There is no timer to keep up with.").font(.subheadline)
                        Button("Mark complete", systemImage: "checkmark") {
                            Task { _ = await store.act(.complete, source: plan, profile: profile, sample: sample, environment: environment, context: context) }
                        }.buttonStyle(.borderedProminent)
                    }
                    Button("Shorter or different", systemImage: "arrow.triangle.branch") { showAlternatives = true }
                        .buttonStyle(.bordered)
                    if !profile.movementsToAvoid.isEmpty && store.record?.movementNoteAtChoice != profile.movementsToAvoid {
                        Text("Review your saved movement restrictions in alternatives before starting.").font(.footnote)
                    }
                } else {
                    Text("Today's plan focuses on another part of your day. You can find a practical alternative here.")
                    Button("See alternatives") { showAlternatives = true }.buttonStyle(.bordered)
                }
                Button("Rest on purpose", systemImage: "leaf") {
                    Task { _ = await store.act(.restOnPurpose, source: plan, profile: profile, sample: sample, environment: environment, context: context) }
                }.buttonStyle(.bordered)
            }
        }.steadyCard().disabled(store.isWorking)
    }

    private func isMovement(_ plan: PlanItem) -> Bool { [.walk, .mobility, .strength, .cardio].contains(plan.type) }

    private func load() async {
        let requestedMode = sample
        let requestedProfileID = profile.id
        let requestedDay = environment.calendar.startOfDay(for: environment.now)
        let loaded = await todayModel.load(profile: profile, environment: environment, useSampleData: requestedMode,
            requestIsCurrent: { requestedMode == sample && requestedProfileID == profile.id })
        guard loaded, !Task.isCancelled, requestedMode == sample, requestedProfileID == profile.id,
              requestedDay == environment.calendar.startOfDay(for: environment.now) else { return }
        await store.load(profile: profile, sample: requestedMode, snapshot: todayModel.snapshot, proposedPlan: todayModel.priority?.planA, environment: environment, context: context)
    }
}

