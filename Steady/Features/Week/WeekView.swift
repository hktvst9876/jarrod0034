import SteadyCore
import SwiftData
import SwiftUI

@MainActor
struct WeekView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("useSampleData") private var sample = false
    let profile: ProfileRecord
    let isSelected: Bool
    @State private var model = WeekViewModel()
    @State private var weekOffset = 0
    @State private var why: WhyItem?
    @State private var experimentEditor = false

    private var request: WeekLoadIdentity {
        WeekLoadIdentity(profile: profile.domainProfile(), sample: sample, weekOffset: weekOffset, selected: isSelected,
            lifecycle: environment.dataLifecycle.revision)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("A short, neutral look back. Retained records are not your whole week; missing information is not zero.")
                    Picker("Review week", selection: $weekOffset) {
                        Text("This week").tag(0)
                        Text("Last week").tag(-1)
                    }.pickerStyle(.segmented)
                    if sample {
                        Label("Sample sleep; local sample records stay separate", systemImage: "flask")
                        Text("Sample evidence cannot propose a change to your real profile defaults.").font(.footnote)
                    }
                }
                if model.isLoading { ProgressView("Reading available context") }
                if let failure = model.failure { Section { Text(failure).foregroundStyle(.secondary) } }
                if let summary = model.summary, !environment.dataLifecycle.isBlocked {
                    WeekSummarySections(summary: summary, lowData: profile.lowDataMode, sleepNote: model.sleepNote, why: $why)
                    experimentSection
                    if let proposal = model.defaultProposal { defaultSection(proposal) }
                    reviewSection
                }
                if let message = model.message { Section { Text(message).foregroundStyle(.secondary) } }
                Section("Your data") {
                    NavigationLink("Export or delete local data") { DataControlsView(profile: profile) }
                    Text("No remote analytics. Clear advisor activity separately in Settings.").font(.footnote)
                }
            }
            .navigationTitle("Week")
            .toolbar { Button("Refresh", systemImage: "arrow.clockwise") { Task { await reload() } } }
            .refreshable { await reload() }
        }
        .task(id: request) { await reload() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.invalidate(); experimentEditor = false }
            else { Task { await reload() } }
        }
        .onDisappear { model.invalidate() }
        .sheet(item: $why) { WhySheet(title: $0.title, explanation: $0.explanation) }
        .sheet(isPresented: $experimentEditor, onDismiss: { model.experimentEditorDismissed() }) {
            WeekExperimentEditor(environment: environment) { kind, start, end in
                model.prepareExperiment(kind: kind, start: start, end: end, environment: environment)
                experimentEditor = false
            }
        }
        .sheet(item: $model.experimentDraft) { draft in
            WeekConfirmation(title: "Confirm one experiment", confirmLabel: "Save experiment", cancel: { model.experimentDraft = nil }, confirm: {
                if model.confirmExperiment(profile: profile, sample: sample, environment: environment, context: context) { Task { await reload() } }
            }) {
                Text(draft.kind.title).font(.headline)
                Text(draft.kind.simpleMeasure)
                Text("Starts \(WeekFormatting.date(draft.start)); ends before \(WeekFormatting.date(draft.endExclusive)).")
                DisclosureGroup("Why these dates") { Text("Your chosen Singapore calendar dates make a bounded trial. The end date is exclusive; no reminder or setting is scheduled.") }
                Text("This saves a local intention only. It does not change defaults, create a plan, or turn on reminders.")
            }
        }
        .sheet(item: $model.reviewedDefault) { proposal in
            WeekConfirmation(title: "Review default change", confirmLabel: "Enable exam mode", cancel: { model.reviewedDefault = nil }, confirm: {
                if model.confirmDefault(profile: profile, sample: sample, environment: environment, context: context) { Task { await reload() } }
            }) {
                Text("Exam mode: off to on").font(.headline)
                Text(proposal.reason)
                Text("Only exam mode changes. Exercise targets, food restrictions, Health, Calendar, and reminders remain unchanged. You can turn it off later in Settings.")
                DisclosureGroup("Why this proposal") { Text("This is based on changed saved plans across distinct days, not wearable recovery scores. It only proposes lighter planning; cancelling changes nothing.") }
            }
        }
    }

    private var experimentSection: some View {
        Section("One small experiment") {
            if let experiment = model.experiment {
                Text(experiment.kind.title).font(.headline)
                Text(experiment.kind.simpleMeasure)
                Text("\(WeekFormatting.date(experiment.start)) until before \(WeekFormatting.date(experiment.endExclusive))")
                Button("Why this interval") { why = WhyItem(title: "A bounded intention", explanation: "These are the dates you explicitly confirmed. This is not a streak, requirement, automatic default change, or evidence of completion.") }
                if experiment.endExclusive <= environment.now { Text("This trial has ended. Reflect on its usefulness below.").foregroundStyle(.secondary) }
                else { Text("Already selected. No second overlapping experiment is added.").foregroundStyle(.secondary) }
            }
            if model.experiment == nil || (model.experiment?.endExclusive ?? environment.now) <= environment.now {
                Button("Choose an experiment") { recordVisible(.experiment); experimentEditor = true }
                    .onAppear { recordVisible(.experiment) }
            }
            Text("Choose a useful intention, or skip it. No catch-up is needed.").font(.footnote)
        }
    }

    private func defaultSection(_ proposal: WeeklyDefaultProposal) -> some View {
        Section("Optional default proposal") {
            Text("Try lighter planning with exam mode")
            Text(proposal.reason).foregroundStyle(.secondary)
            Button("Review proposed change") { recordVisible(.lighterDefault); model.reviewedDefault = model.defaultProposal }
                .onAppear { recordVisible(.lighterDefault) }
            Button("Keep current settings") { model.defaultProposal = nil; model.reviewedDefault = nil }
            Text("Opening or rejecting this proposal changes no setting.").font(.footnote)
        }
    }

    private var reviewSection: some View {
        Section("Your review") {
            Picker("Was this useful?", selection: $model.helpfulness) {
                Text("Not answered").tag(Optional<WeeklyHelpfulness>.none)
                ForEach(WeeklyHelpfulness.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
            }
            if let review = model.review {
                Text("Last reviewed \(WeekFormatting.date(review.reviewedAt))")
                Button("Why this date") { why = WhyItem(title: "Your explicit review", explanation: "This is when you saved a review on this device. It is not automatic activity tracking or proof that every source was available.") }
            }
            Button("Save review") {
                if model.saveReview(profile: profile, sample: sample, environment: environment, context: context) { Task { await reload() } }
            }
            Text("Only the review date and optional answer are saved. Runtime sleep totals are not copied into review history.").font(.footnote)
        }
    }

    private func reload() async {
        guard isSelected, scenePhase == .active else { model.invalidate(); return }
        await model.load(profile: profile, sample: sample, weekOffset: weekOffset, environment: environment, context: context)
    }

    private func recordVisible(_ kind: WeekVisibleSuggestion) {
        guard isSelected, scenePhase == .active, !experimentEditor, why == nil,
              model.experimentDraft == nil, model.reviewedDefault == nil else { return }
        model.recordVisibleSuggestion(kind, profile: profile, sample: sample, environment: environment, context: context)
    }
}

private struct WeekLoadIdentity: Equatable {
    let profile: Profile?
    let sample: Bool
    let weekOffset: Int
    let selected: Bool
    let lifecycle: Int
}

extension WeeklyHelpfulness {
    var title: String {
        switch self { case .helpful: "Helpful"; case .mixed: "Mixed"; case .notHelpful: "Not helpful" }
    }
}

enum WeekFormatting {
    static func date(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = SteadyCalendar.singapore(); formatter.timeZone = formatter.calendar.timeZone
        formatter.dateStyle = .medium; formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

