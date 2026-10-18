import SteadyCore
import SwiftUI

struct SleepView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.scenePhase) private var scenePhase
    let profile: ProfileRecord
    @State private var model = SleepViewModel()
    @State private var why: WhyItem?
    @State private var observedDay: Date?
    @AppStorage("useSampleData") private var useSampleData = false

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    if model.isLoading && model.sleep.lastNight == nil {
                        ProgressView("Reading sleep context…")
                            .padding(.top, 80)
                    } else {
                        lastNightCard
                        recentCard
                        bedtimeCard
                    }
                }
                .padding()
            }
            .navigationTitle("Sleep")
            .refreshable { await reload() }
        }
        .task(id: request) {
            guard scenePhase == .active else { model.invalidate(); return }
            await reload()
        }
        .task(id: scenePhase) {
            guard scenePhase == .active else { return }
            observedDay = environment.calendar.startOfDay(for: environment.now)
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(30)) } catch { return }
                guard !Task.isCancelled, scenePhase == .active else { return }
                observedDay = environment.calendar.startOfDay(for: environment.now)
            }
        }
        .onDisappear { model.invalidate() }
        .onChange(of: profile.lowDataMode) { _, _ in why = nil }
        .sheet(item: $why) { item in
            WhySheet(title: item.title, explanation: item.explanation)
        }
    }

    private var lastNightCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Last night").font(.headline)
            if profile.lowDataMode {
                Text(model.sleep.lastNight == nil ? "No readable sleep data for last night."
                    : "Readable sleep context is available. Duration and wake time are hidden in low-data mode.")
                    .foregroundStyle(.secondary)
                Button("Why these details are hidden") {
                    why = WhyItem(title: "Low-data sleep context", explanation: "Your chosen low-data mode hides measured sleep duration, wake time, shortfall, and consistency labels. Available context can still support planning without displaying a sleep score.")
                }
            } else if let night = model.sleep.lastNight {
                Text(duration(night.asleepMinutes)).font(.title.bold())
                Text("Woke at \(night.wakeTime.formatted(date: .omitted, time: .shortened))")
                    .foregroundStyle(.secondary)
                Button("Why these numbers") {
                    why = WhyItem(
                        title: "Last night",
                        explanation: "Steady merges overlapping sleep stages from Apple Health and counts a night on the date you woke up."
                    )
                }
            } else {
                Text("No readable sleep data for last night.")
                    .font(.title3.bold())
                Text("Steady can still plan from your preferences and check-in.")
                    .foregroundStyle(.secondary)
            }
        }
        .steadyCard()
    }

    private var recentCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent pattern").font(.headline)
            if profile.lowDataMode {
                Text("Sleep duration, shortfall, and consistency labels are hidden in low-data mode.")
                    .foregroundStyle(.secondary)
                LabeledContent("Coverage", value: "\(model.sleep.nightsTracked) tracked nights")
                Button("Why this coverage") {
                    why = WhyItem(title: "Readable sleep coverage", explanation: "This counts nights with readable sleep observations in the recent window. Missing nights remain unknown, never zero sleep; this is coverage, not a sleep score.")
                }
            } else if let shortfall = model.sleep.shortfall7dMinutes {
                LabeledContent("Combined shortfall", value: duration(shortfall))
                LabeledContent("Coverage", value: "\(model.sleep.nightsTracked) tracked nights")
                Button("Why this total") {
                    why = WhyItem(
                        title: "Recent sleep opportunity",
                        explanation: "For each readable night in the recent window, Steady compares sleep duration with your chosen sleep need. Missing nights do not count as zero."
                    )
                }
            } else {
                Text("Not enough readable nights for a recent total.")
                    .foregroundStyle(.secondary)
            }
            if !profile.lowDataMode, let consistency = model.sleep.wakeConsistency {
                LabeledContent("Wake timing", value: consistency.label.title)
                Button("Why this pattern") {
                    why = WhyItem(
                        title: "Wake timing",
                        explanation: "This compares your readable wake times with their recent average. It is context, not a grade."
                    )
                }
            }
        }
        .steadyCard()
    }

    private var bedtimeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tonight").font(.headline)
            if profile.lowDataMode {
                Text("These are optional planning times from your chosen preferences, not measured sleep or a recovery score.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            if let plan = model.sleep.bedtimePlan {
                BedtimeRow(
                    label: "Bedtime window",
                    value: "\(time(plan.bedtimeWindowStart))–\(time(plan.bedtimeWindowEnd))"
                ) {
                    why = WhyItem(title: "Bedtime window", explanation: plan.explanation)
                }
                BedtimeRow(label: "Wind down", value: time(plan.windDownTime)) {
                    why = WhyItem(
                        title: "Wind-down time",
                        explanation: "This starts before the planned bedtime so the smallest useful routine can happen without rushing."
                    )
                }
                BedtimeRow(label: "Caffeine cutoff", value: time(plan.caffeineCutoffTime)) {
                    why = WhyItem(
                        title: "Caffeine cutoff",
                        explanation: "This uses the lead time saved in your sleep preferences. It is guidance, not a restriction."
                    )
                }
                if plan.needsEarlyWakeHeadsUp {
                    Text("Tomorrow starts earlier than your usual wake time.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if plan.isWakeTimeClamped {
                    Text("A commitment may need a wake time earlier than Steady's planning floor. Check the event and travel time directly.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("A bedtime window is unavailable. Check your wake preferences in Settings.")
                    .foregroundStyle(.secondary)
            }
        }
        .steadyCard()
    }

    private func reload() async {
        guard scenePhase == .active else { model.invalidate(); return }
        let requestedMode = useSampleData
        let requestedProfile = profile.domainProfile()
        await model.load(profile: profile, environment: environment, useSampleData: requestedMode,
            requestIsCurrent: { scenePhase == .active && requestedMode == useSampleData
                && requestedProfile == profile.domainProfile() })
    }

    private var request: SleepLoadIdentity {
        SleepLoadIdentity(profile: profile.domainProfile(), sample: useSampleData,
            day: observedDay ?? environment.calendar.startOfDay(for: environment.now),
            active: scenePhase == .active, privacyRevision: environment.dataLifecycle.revision)
    }

    private func duration(_ minutes: Int) -> String {
        Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    private func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

private struct SleepLoadIdentity: Equatable {
    let profile: Profile?
    let sample: Bool
    let day: Date
    let active: Bool
    let privacyRevision: Int
}

private struct BedtimeRow: View {
    let label: String
    let value: String
    let showWhy: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(label).font(.subheadline)
                Text(value).font(.title3.bold())
            }
            Spacer()
            Button("Why", systemImage: "info.circle", action: showWhy)
                .labelStyle(.iconOnly)
        }
    }
}

private extension WakeConsistencyLabel {
    var title: String {
        switch self {
        case .steady: "Steady"
        case .aBitIrregular: "A little varied"
        case .irregular: "Varied"
        }
    }
}
